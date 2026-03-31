---@diagnostic disable
local helpers = require("suites.gameplay.gameplay_cases_helpers")

local _modules = {
  "suites.gameplay.gameplay_cases_bankruptcy",
  "suites.gameplay.gameplay_cases_runtime_context",
  "suites.gameplay.gameplay_cases_auto_runner",
  "suites.gameplay.gameplay_cases_turn_flow",
  "suites.gameplay.gameplay_cases_loop_policies",
  "suites.gameplay.gameplay_cases_misc",
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
