local effect_executor = require("src.rules.effects.executor")
local Class = require("src.foundation.class")

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

function effect_registry:register_defaults(groups)
  for _, group in ipairs(groups or {}) do
    self:register_many(group)
  end
end

function effect_registry:get(effect_id)
  return self.executors[effect_id]
end

return effect_registry

--[[ mutate4lua-manifest
version=4
projectHash=e4093820871df5cd
scope.0.id=chunk:src/rules/effects/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=32
scope.0.semanticHash=f2ddbea9982b513b
scope.1.id=function:effect_registry:init
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=71cf7d660694c7cf
scope.2.id=function:effect_registry:register
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=13
scope.2.semanticHash=266a031c9d3d4279
scope.3.id=function:effect_registry:register_many
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=19
scope.3.semanticHash=7a6f9afa4cca511c
scope.4.id=function:effect_registry:register_defaults
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=25
scope.4.semanticHash=25db60f5fa243bcf
scope.5.id=function:effect_registry:get
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=29
scope.5.semanticHash=70ade069282003e1
]]
