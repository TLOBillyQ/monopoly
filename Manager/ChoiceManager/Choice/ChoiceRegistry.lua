local ChoiceRegistry = {}
local handlers = {}
local defaults_registered = false

ChoiceRegistry.handlers = handlers

function ChoiceRegistry.register(kind, handler)
  handlers[kind] = handler
end

function ChoiceRegistry.register_defaults(helpers)
  if defaults_registered then
    return
  end
  defaults_registered = true
  local groups = {
    require("Manager.ChoiceManager.Choice.ChoiceHandlers.OptionalEffectHandler").build(helpers),
    require("Manager.ChoiceManager.Choice.ChoiceHandlers.LandChoiceHandler").build(helpers),
    require("Manager.ChoiceManager.Choice.ChoiceHandlers.ItemChoiceHandler").build(helpers),
    require("Manager.ChoiceManager.Choice.ChoiceHandlers.MarketChoiceHandler").build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      ChoiceRegistry.register(key, handler)
    end
  end
end

return ChoiceRegistry
