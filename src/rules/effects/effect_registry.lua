local effect_executor = require("src.rules.effects.effect_executor")
require "vendor.third_party.ClassUtils"

local effect_registry = Class("EffectRegistry")

function effect_registry:init()
  self.executors = {}
end

function effect_registry:register(effect_id, executor)
  effect_executor.validate(effect_id, executor)
  self.executors[effect_id] = executor
end

function effect_registry:register_many(entries)
  for effect_id, executor in pairs(entries or {}) do
    self:register(effect_id, executor)
  end
end

function effect_registry:get(effect_id)
  return self.executors[effect_id]
end

return effect_registry
