local effect_executor = require("src.rules.effects.executor")
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

--[[ mutate4lua-manifest
version=2
projectHash=7ee9353a4cf1e78d
scope.0.id=chunk:src/rules/effects/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=c3fb61afe9e6a0d2
scope.1.id=function:effect_registry:init:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=20ffeca90b5ac2cb
scope.2.id=function:effect_registry:register:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=13
scope.2.semanticHash=a2ec7a68ace179ee
scope.3.id=function:effect_registry:get:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=56272fe01250d50a
]]
