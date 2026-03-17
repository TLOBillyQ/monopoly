local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local tooling_parallel = require("tests.support.tooling_parallel")
local timing_summary = require("tests.support.timing_summary")

local M = {}

local function _help_text()
  return table.concat({
    "用法: lua tests/tooling.lua [--workers N]",
    "Usage: lua tests/tooling.lua [--workers N]",
    "",
    "默认并行执行 tooling suites。",
    "Tooling suites run in parallel by default.",
    "  --workers 1    串行运行，便于调试",
    "  --workers N    显式指定并发度",
  }, "\n")
end

local function _parse_args(args)
  local options = {
    workers = nil,
    help = false,
  }

  local index = 1
  while index <= #(args or {}) do
    local token = args[index]
    if token == "--help" or token == "-h" then
      options.help = true
    elseif token == "--workers" then
      index = index + 1
      local value = args[index]
      if value == nil or value == "" then
        error("--workers requires a value")
      end
      options.workers = value
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  return options
end

function M.run(args)
  bootstrap.install_package_paths()
  local options = _parse_args(args or arg or {})
  if options.help then
    print(_help_text())
    return 0
  end
  local result = tooling_parallel.run(catalog.load_tooling_suites(), {
    capture_logs = true,
    workers = options.workers,
  })
  timing_summary.print_lane_summary("tooling", result)
  return result
end

function M.main()
  return M.run(arg or {})
end

if ... == "tests.tooling" then
  return M
end

M.main()
