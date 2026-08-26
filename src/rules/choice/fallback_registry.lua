local M = {}

local _registry = {}

function M.register(kind, fn)
  assert(type(kind) == "string" and kind ~= "", "invalid kind")
  assert(type(fn) == "function", "invalid fallback fn")
  _registry[kind] = fn
end

function M.resolve(kind, game, choice)
  if type(kind) ~= "string" then
    return nil
  end
  local fn = _registry[kind]
  if type(fn) ~= "function" then
    return nil
  end
  local ok, action = pcall(fn, game, choice)
  if not ok then
    return nil
  end
  return action
end

function M.reset()
  _registry = {}
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=0013ac92da1d0801
scope.0.id=chunk:src/rules/choice/fallback_registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=4aa3e11b2800788a
scope.1.id=function:M.register
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=9
scope.1.semanticHash=66bf351b37ab6206
scope.2.id=function:M.resolve
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=24
scope.2.semanticHash=9a18f4a733a0c427
scope.3.id=function:M.reset
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=d7c2a6e6b915f0cd
]]
