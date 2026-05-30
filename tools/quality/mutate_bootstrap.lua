local function _normalize_path(path)
  return (tostring(path or ""):gsub("\\", "/"))
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/mutate_bootstrap.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
require("shared.mutate4lua_paths").activate(bootstrap_env.vendor_dir)

local util = require("mutate4lua.util")
local manifest = require("mutate4lua.internal.manifest")
local scanner = require("mutate4lua.internal.scanner")
local project = require("mutate4lua.driver.project")

local M = {}

local _END_MARKER = "]]"

function M.classify_source(source)
  if source == nil or source == "" then
    return { state = "no_manifest" }
  end
  source = util.normalize_newlines(source)
  local start_at = source:match("()" .. "%-%-%[%[ mutate4lua%-manifest\n")
  if not start_at then
    return { state = "no_manifest" }
  end
  local tail = source:sub(start_at)
  if util.trim(tail):sub(-2) ~= _END_MARKER then
    return { state = "corrupt", reason = "missing end marker" }
  end
  return { state = "has_manifest" }
end

function M.is_bootstrap_only(manifest_data)
  if manifest_data == nil then
    return false
  end
  local scopes = manifest_data.scopes
  if scopes == nil or #scopes == 0 then
    return false
  end
  for _, scope in ipairs(scopes) do
    if scope.last_mutation_status ~= nil then
      return false
    end
  end
  return true
end

function M.detect_drift(existing_scopes, current_scopes)
  if existing_scopes == nil or current_scopes == nil then
    return true
  end
  if #existing_scopes ~= #current_scopes then
    return true
  end
  for i = 1, #existing_scopes do
    local a = existing_scopes[i] or {}
    local b = current_scopes[i] or {}
    if a.id ~= b.id then return true end
    if a.semantic_hash ~= b.semantic_hash then return true end
  end
  return false
end

local function _categorize(file_path, runtime)
  local source, read_err = runtime.read_source(file_path)
  if source == nil then
    return { path = file_path, action = "skipped", reason = read_err or "cannot read" }
  end

  local classification = M.classify_source(source)
  if classification.state == "corrupt" then
    return { path = file_path, action = "skipped", reason = classification.reason }
  end

  local data, scan_err = runtime.scan_file(file_path)
  if data == nil then
    return { path = file_path, action = "skipped", reason = scan_err or "scan failed" }
  end

  if classification.state == "no_manifest" then
    return { path = file_path, action = "written", data = data }
  end

  local existing = runtime.read_manifest(file_path)
  if existing == nil then
    return { path = file_path, action = "written", data = data }
  end

  local version = tonumber(existing.version) or 1
  if version < 2 then
    return { path = file_path, action = "migrated", data = data }
  end

  if M.detect_drift(existing.scopes, data.scopes) then
    return { path = file_path, action = "written", data = data }
  end

  return { path = file_path, action = "unchanged" }
end

function M.run(opts, runtime)
  opts = opts or {}
  local files = runtime.list_src_lua_files()
  if files == nil or #files == 0 then
    runtime.err_write("[mutate-bootstrap] 无 src 文件，跳过\n")
    return { exit_code = 0, total = 0, written = {}, migrated = {}, unchanged = {}, skipped = {} }
  end

  local buckets = { written = {}, migrated = {}, unchanged = {}, skipped = {} }
  for _, file_path in ipairs(files) do
    local outcome = _categorize(file_path, runtime)
    if outcome.action == "skipped" then
      runtime.err_write(string.format(
        "[mutate-bootstrap] skip %s: %s\n", outcome.path, tostring(outcome.reason or "unknown")
      ))
    elseif not opts.dry_run and (outcome.action == "written" or outcome.action == "migrated") then
      runtime.write_manifest(outcome.path, outcome.data)
    end
    table.insert(buckets[outcome.action], outcome.path)
  end

  local prefix = opts.dry_run and "will-" or ""
  runtime.out_write(string.format(
    "[mutate-bootstrap] total=%d %swritten=%d %smigrate=%d %sunchanged=%d %sskip=%d\n",
    #files,
    prefix, #buckets.written,
    prefix, #buckets.migrated,
    prefix, #buckets.unchanged,
    prefix, #buckets.skipped
  ))

  return {
    exit_code = 0,
    total = #files,
    written = buckets.written,
    migrated = buckets.migrated,
    unchanged = buckets.unchanged,
    skipped = buckets.skipped,
  }
end

local function _read_command(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if handle == nil then return nil, "popen failed" end
  local out = handle:read("*a")
  handle:close()
  return out or ""
end

local function _default_list_src_lua_files()
  local out = _read_command("git ls-files -- 'src/*.lua'")
  if out == nil then return {} end
  local files = {}
  for line in out:gmatch("([^\n]+)") do
    if line:match("%.lua$") and line:sub(1, 4) == "src/" then
      files[#files + 1] = line
    end
  end
  table.sort(files)
  return files
end

local function _default_read_source(path)
  local f = io.open(path, "r")
  if not f then return nil, "cannot open " .. path end
  local body = f:read("*a")
  f:close()
  return body
end

local function _default_read_manifest(path)
  local ok, data = pcall(manifest.read, path)
  if not ok then return nil end
  return data
end

local function _default_scan_file(path)
  local source, read_err = _default_read_source(path)
  if source == nil then return nil, read_err end
  local stripped = manifest.strip(source)
  local abs = util.absolute_path(util.join_path(bootstrap_env.repo_root, path))
  local relative = project.relative_file(bootstrap_env.repo_root, abs)
  local ok, data = pcall(scanner.analyze, abs, relative, stripped)
  if not ok then return nil, tostring(data) end
  data._abs = abs
  data._stripped = stripped
  return data
end

local function _default_write_manifest(_, data)
  local proj_hash = project.project_hash(
    project.find_root(bootstrap_env.repo_root, data._abs),
    data._abs,
    data._stripped
  )
  manifest.write(data._abs, data._stripped, {
    version = 2,
    project_hash = proj_hash,
    scopes = data.scopes,
  })
end

function M.main(argv)
  local opts = { dry_run = false }
  for _, a in ipairs(argv or {}) do
    if a == "--dry-run" then
      opts.dry_run = true
    elseif a == "--help" or a == "-h" then
      io.write([[
用法: lua tools/quality/mutate_bootstrap.lua [选项]
Usage: lua tools/quality/mutate_bootstrap.lua [options]

为 src/**/*.lua 一次性 bootstrap mutate4lua v2 manifest 尾块。
Bootstrap mutate4lua v2 manifest tails across src/**/*.lua.

选项 / Options:
  --dry-run    预览分类计数，不写文件 / preview classification, do not write
  --help       显示帮助 / show help
]])
      return 0
    else
      io.stderr:write("unknown argument: ", tostring(a), "\n")
      return 1
    end
  end

  local runtime = {
    list_src_lua_files = _default_list_src_lua_files,
    read_source = _default_read_source,
    read_manifest = _default_read_manifest,
    scan_file = _default_scan_file,
    write_manifest = _default_write_manifest,
    out_write = function(s) io.stdout:write(s) end,
    err_write = function(s) io.stderr:write(s) end,
  }
  local result = M.run(opts, runtime)
  return result.exit_code
end

if ... == "quality.mutate_bootstrap" then
  return M
end

os.exit(M.main(arg or {}))
