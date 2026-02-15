require "vendor.third_party.ClassUtils"

local choice_registry = Class("ChoiceRegistry")

function choice_registry:init()
  self.handlers = {}
end

function choice_registry:register(kind, handler)
  self.handlers[kind] = handler
end

function choice_registry:register_defaults(helpers)
  local groups = {
    require("src.game.systems.choices.ChoiceHandlers.OptionalEffectHandler").build(helpers),
    require("src.game.systems.choices.ChoiceHandlers.LandChoiceHandler").build(helpers),
    require("src.game.systems.choices.ChoiceHandlers.ItemChoiceHandler").build(helpers),
    require("src.game.systems.choices.ChoiceHandlers.MarketChoiceHandler").build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      self:register(key, handler)
    end
  end
end

return choice_registry
