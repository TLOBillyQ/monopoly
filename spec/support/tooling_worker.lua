require("spec.bootstrap").install_package_paths()

local catalog = require("tests.catalog")
local harness = require("TestHarness")
local common = require("shared.lib.common")
local json_writer = require("arch_view.runtime.json_writer")

local M = {}

local function _silent_reporter()
  return {
    case_pass = function() end,
    case_fail = function() end,
    finish = function() end,
  }
end

local function _parse_args(args)
  local options = {
    suite_module = nil,
    result_file = nil,
  }

  local index = 1
  while index <= #(args or {}) do
    local token = args[index]
    if token == "--suite-module" then
      index = index + 1
      options.suite_module = args[index]
    elseif token == "--result-file" then
      index = index + 1
      options.result_file = args[index]
    else
      error("unknown flag: " .. tostring(token))
    end
    index = index + 1
  end

  if options.suite_module == nil or options.suite_module == "" then
    error("--suite-module requires a value")
  end
  if options.result_file == nil or options.result_file == "" then
    error("--result-file requires a value")
  end

  return options
end

local function _find_suite(suite_module)
  for _, suite in ipairs(catalog.load_tooling_suites()) do
    if suite.module_name == suite_module then
      return suite
    end
  end
  return nil
end

function M.run(args)
  local options = _parse_args(args or arg or {})
  local suite = _find_suite(options.suite_module)
  if suite == nil then
    error("tooling suite not found: " .. tostring(options.suite_module))
  end

  local ok, result_or_err = xpcall(function()
    return harness.run_all({ suite }, {
      capture_logs = true,
      quiet = true,
      reporter = _silent_reporter(),
      raise_on_failure = false,
    })
  end, debug.traceback)

  local payload = {
    ok = ok,
    suite_module = suite.module_name,
    suite_name = suite.name,
  }
  if ok then
    payload.result = result_or_err
  else
    payload.error = result_or_err
  end

  local write_ok, write_err = common.write_file(options.result_file, json_writer.encode(payload) .. "\n")
  if not write_ok then
    error(write_err)
  end

  if not ok then
    return 1
  end
  return 0
end

function M.main()
  return M.run(arg or {})
end

if ... == "tests.support.tooling_worker" then
  return M
end

os.exit(M.main())
