require "lib.third_party.ClassUtils"

local chance_registry = Class("ChanceRegistry")

function chance_registry:init()
  self.handlers = {}
end

function chance_registry:register(effect, handler)
  self.handlers[effect] = handler
end

function chance_registry:register_defaults()
  local effects = require("chance.effects")
  effects.register(self)
end

return chance_registry
