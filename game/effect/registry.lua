local executor = require("game.effect.executor")
require "lib.third_party.ClassUtils"

local registry = Class("EffectRegistry")

function registry:init()
  self.executors = {}
end

function registry:register(effect_id, exec)
  executor.validate(effect_id, exec)
  self.executors[effect_id] = exec
end

function registry:register_many(entries)
  for effect_id, exec in pairs(entries or {}) do
    self:register(effect_id, exec)
  end
end

function registry:get(effect_id)
  return self.executors[effect_id]
end

return registry
