---@diagnostic disable
local helpers = require("suites.gameplay.shared.helpers")

local _modules = {
  "suites.gameplay.bankruptcy.cases",
  "suites.gameplay.runtime.cases",
  "suites.gameplay.auto_runner.cases",
  "suites.gameplay.turn_flow.cases",
  "suites.gameplay.turn_flow.loop_policies",
  "suites.gameplay.shared.misc_cases",
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
