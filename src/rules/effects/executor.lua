local effect_executor = {}

function effect_executor.validate(effect_id, executor)
  assert(effect_id ~= nil and effect_id ~= "", "missing effect_id")
  assert(type(executor) == "table", "invalid executor: " .. tostring(effect_id))
  assert(type(executor.apply) == "function", "missing executor apply: " .. tostring(effect_id))
end

return effect_executor

--[[ mutate4lua-manifest
version=4
projectHash=b918d1ee71f927f1
scope.0.id=chunk:src/rules/effects/executor.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=10
scope.0.semanticHash=0df5bda46ef7ae1d
scope.1.id=function:effect_executor.validate
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=7
scope.1.semanticHash=981eac5cd0953cab
]]
