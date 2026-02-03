local choice_registry = {}
local handlers = {}
local defaults_registered = false

choice_registry.handlers = handlers

function choice_registry.register(kind, handler)
  handlers[kind] = handler
end

function choice_registry.register_defaults(helpers)
  if defaults_registered then
    return
  end
  defaults_registered = true
  local groups = {
    require("src.game.choice.ChoiceHandlers.OptionalEffectHandler").build(helpers),
    require("src.game.choice.ChoiceHandlers.LandChoiceHandler").build(helpers),
    require("src.game.choice.ChoiceHandlers.ItemChoiceHandler").build(helpers),
    require("src.game.choice.ChoiceHandlers.MarketChoiceHandler").build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      choice_registry.register(key, handler)
    end
  end
end

return choice_registry
