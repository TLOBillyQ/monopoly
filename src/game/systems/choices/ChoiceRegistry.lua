local registry = {}

local handlers = {}
local defaults_registered = false

registry.handlers = handlers

function registry.register(kind, handler)
  handlers[kind] = handler
end

function registry.register_defaults(helpers)
  if defaults_registered then
    return
  end
  defaults_registered = true
  local groups = {
    require("src.game.systems.choices.ChoiceHandlers.OptionalEffectHandler").build(helpers),
    require("src.game.systems.choices.ChoiceHandlers.LandChoiceHandler").build(helpers),
    require("src.game.systems.choices.ChoiceHandlers.ItemChoiceHandler").build(helpers),
    require("src.game.systems.choices.ChoiceHandlers.MarketChoiceHandler").build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      registry.register(key, handler)
    end
  end
end

return registry
