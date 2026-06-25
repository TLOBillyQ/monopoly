local quality_steps = {}

local module_names = {
  "acceptance.steps.quality.setup_steps",
  "acceptance.steps.quality.scope_steps",
  "acceptance.steps.quality.mutation_result_steps",
  "acceptance.steps.quality.bootstrap_steps",
  "acceptance.steps.quality.bootstrap_summary_steps",
}

local function _merge(target, source)
  for key, handler in pairs(source) do
    target[key] = handler
  end
end

local function _handlers_for(module_name)
  local module = require(module_name)
  if type(module) ~= "table" or type(module.handlers) ~= "function" then
    error("invalid quality step module: " .. tostring(module_name))
  end
  return module.handlers()
end

function quality_steps.handlers()
  local handlers = {}
  for _, module_name in ipairs(module_names) do
    _merge(handlers, _handlers_for(module_name))
  end
  return handlers
end

return quality_steps
