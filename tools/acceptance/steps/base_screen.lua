-- base_screen step-handler aggregator.
--
-- Behavior-preserving split of the former 802-line base_screen step module
-- into focused sub-modules behind this thin aggregator. Each sub-module owns a
-- disjoint slice of the Gherkin handler set; `handlers()` here merges them
-- back into the same 1:1 handler map, so the public API consumed by
-- tools/acceptance/steps.lua is unchanged.
--
-- Shared support (requires, lookup tables, and pure helpers) lives in
-- base_screen/context.lua and is required by each sub-module.

local module_names = {
  "acceptance.steps.base_screen.role_observance_steps",
  "acceptance.steps.base_screen.phase_state_steps",
  "acceptance.steps.base_screen.assert_steps",
  "acceptance.steps.base_screen.end_button_steps",
  "acceptance.steps.base_screen.flow_outcome_steps",
  "acceptance.steps.base_screen.action_completion_steps",
}

local function _merge(target, source)
  for key, handler in pairs(source) do
    target[key] = handler
  end
end

local function _handlers_for(module_name)
  local module = require(module_name)
  if type(module) ~= "table" or type(module.handlers) ~= "function" then
    error("invalid base_screen step module: " .. tostring(module_name))
  end
  return module.handlers()
end

local base_screen_steps = {}

function base_screen_steps.handlers()
  local handlers = {}
  for _, module_name in ipairs(module_names) do
    _merge(handlers, _handlers_for(module_name))
  end
  return handlers
end

return base_screen_steps