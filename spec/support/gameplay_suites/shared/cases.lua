---@diagnostic disable
local helpers = require("spec.support.gameplay_suites.shared.helpers")

local _modules = {
  "spec.support.gameplay_suites.bankruptcy.cases",
  "spec.support.gameplay_suites.runtime.cases",
  "spec.support.gameplay_suites.auto_runner.cases",
  "spec.support.gameplay_suites.turn_flow.cases",
  "spec.support.gameplay_suites.turn_flow.loop_policies",
  "spec.support.gameplay_suites.shared.misc_cases",
}

local function _merge_cases(target, source)
  for key, value in pairs(source or {}) do
    target[key] = value
  end
end

local _cases = {}
_merge_cases(_cases, helpers.extra_cases())
for _, module_name in ipairs(_modules) do
  local module = require(module_name)
  _merge_cases(_cases, module.make_cases(helpers))
end

return _cases
