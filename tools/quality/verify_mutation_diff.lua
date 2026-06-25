local function _normalize_path(path)
  return (tostring(path or ""):gsub("\\", "/"))
end
local function _module_dir()
  local source = debug.getinfo(1, "S").source or "@tools/quality/verify_mutation_diff.lua"
  return _normalize_path(source):gsub("^@", ""):match("^(.*)/[^/]+$") or "tools/quality"
end

local bootstrap = dofile(_module_dir() .. "/../shared/bootstrap.lua")
local bootstrap_env = bootstrap.install((arg and arg[0]) or debug.getinfo(1, "S").source)
local mutate_tool = assert(bootstrap.ensure_tool("mutate4lua", bootstrap_env))
require("shared.mutate4lua_paths").activate(mutate_tool.root)

local core = require("quality.mutate.diff_core")
local runtime_builder = require("quality.mutate.diff_runtime")

local M = {}

local _DEFAULT_BASE = "main"

M.parse_name_status = core.parse_name_status
M.filter_changed_src = core.filter_changed_src
M.run = core.run

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

  local result = core.run(opts, runtime_builder.build())
  return result.exit_code
end

if ... == "quality.verify_mutation_diff" then
  return M
end

os.exit(M.main(arg or {}))
