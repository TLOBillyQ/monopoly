local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local config_reset = require("tests.support.config_reset")

local M = {}

function M.run(opts)
  opts = opts or {}
  local before_case_hook = opts.before_case
  local after_case_hook = opts.after_case
  bootstrap.install_package_paths()
  local result = harness.run_all(catalog.load_behavior_suites(), {
    before_case = function(context)
      config_reset.reset_all()
      if type(before_case_hook) == "function" then
        before_case_hook(context)
      end
    end,
    after_case = function(context, ok, err, captured)
      config_reset.reset_all()
      if type(after_case_hook) == "function" then
        after_case_hook(context, ok, err, captured)
      end
    end,
    capture_logs = opts.capture_logs ~= false,
    reporter = opts.reporter or harness.quiet_reporter(),
    summary_label = opts.summary_label or "behavior",
  })
  return result
end

function M.main()
  M.run()
end

if ... == nil then
  M.main()
else
  return M
end
