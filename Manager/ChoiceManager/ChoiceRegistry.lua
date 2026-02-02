local ChoiceRegistry = {}
local handlers = {}
local defaults_registered = false

ChoiceRegistry.handlers = handlers

function ChoiceRegistry.Register(kind, handler)
  handlers[kind] = handler
end

function ChoiceRegistry.RegisterDefaults(helpers)
  if defaults_registered then
    return
  end
  defaults_registered = true
  local groups = {
    require("Manager.ChoiceManager.ChoiceHandlers.OptionalEffectHandler").Build(helpers),
    require("Manager.ChoiceManager.ChoiceHandlers.LandChoiceHandler").Build(helpers),
    require("Manager.ChoiceManager.ChoiceHandlers.ItemChoiceHandler").Build(helpers),
    require("Manager.ChoiceManager.ChoiceHandlers.MarketChoiceHandler").Build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      ChoiceRegistry.Register(key, handler)
    end
  end
end

return ChoiceRegistry
