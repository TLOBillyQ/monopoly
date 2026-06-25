local function _normalize_path(path)
  return (tostring(path or ""):gsub("\\", "/"))
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/mutate_bootstrap.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local mutate_tool = assert(bootstrap.ensure_tool("mutate4lua", bootstrap_env))
require("shared.mutate4lua_paths").activate(mutate_tool.root)

local runtime_builder = require("quality.mutate.bootstrap_runtime")
local policy = require("quality.mutation_manifest_policy")

local M = {}

M.classify_source = policy.classify_source
M.is_bootstrap_only = policy.is_bootstrap_only
M.detect_drift = policy.detect_drift

local function _should_write_manifest(action)
  return action == policy.BOOTSTRAP_WRITTEN
      or action == policy.BOOTSTRAP_MIGRATED
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
    local outcome = policy.categorize_bootstrap(file_path, runtime)
    if outcome.action == policy.BOOTSTRAP_SKIPPED then
      runtime.err_write(string.format(
        "[mutate-bootstrap] skip %s: %s\n", outcome.path, tostring(outcome.reason or "unknown")
      ))
    elseif not opts.dry_run and _should_write_manifest(outcome.action) then
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

  local runtime = runtime_builder.build(bootstrap_env)
  local result = M.run(opts, runtime)
  return result.exit_code
end

if ... == "quality.mutate_bootstrap" then
  return M
end

os.exit(M.main(arg or {}))
