require "lib.third_party.ClassUtils"

local choice_registry = Class("ChoiceRegistry")

function choice_registry:init()
  self.handlers = {}
end

function choice_registry:register(kind, handler)
  self.handlers[kind] = handler
end

function choice_registry:register_defaults(helpers)
  local groups = {
    require("choice.handler.effect").build(helpers),
    require("choice.handler.land").build(helpers),
    require("choice.handler.item").build(helpers),
    require("choice.handler.shop").build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      self:register(key, handler)
    end
  end
end

return choice_registry
