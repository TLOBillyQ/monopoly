local ChoiceRegistry = {}
local handlers = {}
local defaults_registered = false

function ChoiceRegistry.register(kind, handler)
  handlers[kind] = handler
end

function ChoiceRegistry.get(kind)
  return handlers[kind]
end

function ChoiceRegistry.register_defaults(deps, helpers)
  if defaults_registered then
    return
  end
  defaults_registered = true
  if not deps then
    return
  end
  local groups = {
    deps.optional_effect_handler.build(helpers),
    deps.land_choice_handler.build(helpers),
    deps.item_choice_handler.build(helpers),
    deps.market_choice_handler.build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      ChoiceRegistry.register(key, handler)
    end
  end
end

return ChoiceRegistry
