local function _normalize_path(path)
  return (tostring(path or ""):gsub("\\", "/"))
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/verify_mutation_diff.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
require("shared.mutate4lua_paths").activate(bootstrap_env.vendor_dir)

local common = require("shared.lib.common")
local util = require("mutate4lua.util")
local manifest_policy = require("quality.mutation_manifest_policy")

local M = {}

local _SRC_LUA_PATTERN = "^src/.+%.lua$"
local _DEFAULT_BASE = "main"

local function _split_lines(text)
  local lines = {}
  for line in (text or ""):gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  return lines
end

function M.parse_name_status(text)
  local entries = {}
  for _, line in ipairs(_split_lines(text)) do
    if line ~= "" then
      local status_letter = line:sub(1, 1)
      if status_letter == "R" or status_letter == "C" then
        local _, dest = line:match("\t([^\t]+)\t([^\t]+)$")
        if dest then
          entries[#entries + 1] = { status = status_letter, path = dest }
        end
      else
        local path = line:match("\t(.+)$")
        if path then
          entries[#entries + 1] = { status = status_letter, path = path }
        end
      end
    end
  end
  return entries
end

function M.filter_changed_src(entries)
  local kept = {}
  for _, entry in ipairs(entries or {}) do
    if entry.status ~= "D" and entry.path:find(_SRC_LUA_PATTERN) then
      kept[#kept + 1] = entry
    end
  end
  return kept
end

local function _format_warning(file, json)
  return string.format(
    "[verify-mutation-diff] %s: survived=%d killed=%d total=%d score=%.1f\n",
    file,
    json.survived or 0,
    json.killed or 0,
    json.total_sites or 0,
    tonumber(json.score) or 0
  )
end

function M.run(opts, runtime)
  opts = opts or {}
  local base = opts.base or _DEFAULT_BASE
  local diff_text, diff_err = runtime.diff_name_status(base)
  if diff_text == nil then
    runtime.err_write(string.format(
      "[verify-mutation-diff] git diff failed: %s\n", tostring(diff_err)
    ))
    return { exit_code = 1, processed = {} }
  end

  local changed = M.filter_changed_src(M.parse_name_status(diff_text))
  if #changed == 0 then
    runtime.err_write("[verify-mutation-diff] 无 src 变更，跳过\n")
    return { exit_code = 0, processed = {} }
  end

  local processed = {}
  local survived_count = 0

  for _, entry in ipairs(changed) do
    local file = entry.path
    local result = runtime.mutate_file(file)
    if result.exit_code == 1 then
      runtime.err_write(string.format(
        "[verify-mutation-diff] baseline failure for %s — aborting\n", file
      ))
      if result.stderr and result.stderr ~= "" then
        runtime.err_write(result.stderr)
        if result.stderr:sub(-1) ~= "\n" then runtime.err_write("\n") end
      end
      return { exit_code = 1, processed = processed }
    end

    local summary = manifest_policy.summarize_mutation_result(file, result.json or {})
    processed[#processed + 1] = {
      file = summary.file,
      total_sites = summary.total_sites,
      killed = summary.killed,
      survived = summary.survived,
      timeout = summary.timeout,
      score = summary.score,
    }
    if summary.has_survived then
      survived_count = survived_count + 1
      runtime.err_write(_format_warning(file, summary))
    end
  end

  if opts.json then
    runtime.out_write(util.encode_json({ files = processed }))
    runtime.out_write("\n")
  end

  if survived_count > 0 then
    runtime.err_write(string.format(
      "[verify-mutation-diff] %d file(s) had survived mutants — review above\n",
      survived_count
    ))
  end

  return { exit_code = 0, processed = processed }
end

local function _read_command(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if handle == nil then
    return nil, "popen failed"
  end
  local out = handle:read("*a")
  handle:close()
  return out or ""
end

local function _default_diff_name_status(base)
  local cmd = "git diff --name-status " .. common.shell_quote(base .. "...HEAD")
  return _read_command(cmd)
end

local function _make_buffer_writer()
  local chunks = {}
  local writer = {}
  function writer:write(...)
    for i = 1, select("#", ...) do
      chunks[#chunks + 1] = tostring((select(i, ...)))
    end
    return self
  end
  function writer.text()
    return table.concat(chunks)
  end
  return writer
end

local _mutate_module
local _mutate_cli

local function _ensure_mutate_loaded()
  if _mutate_module ~= nil then
    return
  end
  _mutate_module = require("quality.mutate")
  _mutate_cli = require("mutate4lua.cli")
end

local function _default_mutate_file(file)
  _ensure_mutate_loaded()
  local stdout = _make_buffer_writer()
  local stderr = _make_buffer_writer()

  if not _mutate_module.check_bootstrap_only(file, function(t) stderr:write(t) end) then
    return { exit_code = 1, json = nil, stderr = stderr.text() }
  end

  local call_env = {}
  for k, v in pairs(_mutate_module.env) do
    call_env[k] = v
  end
  call_env.stdout = stdout
  call_env.stderr = stderr

  local ok, exit_or_err = pcall(_mutate_cli.run, { file, "--json" }, call_env)
  local exit_code
  if ok then
    exit_code = tonumber(exit_or_err) or 0
  else
    exit_code = 1
    stderr:write(tostring(exit_or_err), "\n")
  end

  local stdout_text = stdout.text()
  local stderr_text = stderr.text()

  local json_ok, json_value = pcall(util.decode_json, stdout_text)
  return {
    exit_code = exit_code,
    json = json_ok and type(json_value) == "table" and json_value or nil,
    stderr = stderr_text,
  }
end

function M.main(argv)
  local opts = { base = _DEFAULT_BASE, json = false }
  local i = 1
  while i <= #(argv or {}) do
    local a = argv[i]
    if a == "--base" then
      i = i + 1
      opts.base = argv[i]
    elseif a == "--json" then
      opts.json = true
    elseif a == "--help" or a == "-h" then
      io.write([[
用法: lua tools/quality/verify_mutation_diff.lua [选项]
Usage: lua tools/quality/verify_mutation_diff.lua [options]

选项 / Options:
  --base REF   基准引用 / diff base reference (default: main)
  --json       JSON 聚合输出到 stdout / aggregate JSON to stdout
  --help       显示帮助 / show help
]])
      return 0
    else
      io.stderr:write("unknown argument: ", tostring(a), "\n")
      return 1
    end
    i = i + 1
  end

  local runtime = {
    diff_name_status = _default_diff_name_status,
    mutate_file = _default_mutate_file,
    out_write = function(s) io.stdout:write(s) end,
    err_write = function(s) io.stderr:write(s) end,
  }
  local result = M.run(opts, runtime)
  return result.exit_code
end

if ... == "quality.verify_mutation_diff" then
  return M
end

os.exit(M.main(arg or {}))
