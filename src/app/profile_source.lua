local source = {}
local default_map_module = "src.config.content.default_map"

local function _require_default_map()
  local ok, map_or_err = pcall(require, default_map_module)
  assert(ok, "failed to require default map module: " .. tostring(map_or_err))
  return map_or_err
end

local function _resolve_testing_bootstrap(profile_name)
  if type(profile_name) ~= "string" or profile_name == "" or profile_name == "default" then
    return {}
  end
  local resolver = require("src.app.testing.test_profile_resolver")
  return resolver.resolve_bootstrap(profile_name)
end

function source.resolve_map()
  return _require_default_map()
end

function source.resolve_bootstrap(startup)
  return _resolve_testing_bootstrap(startup and startup.profile_name or nil)
end

return source

--[[ mutate4lua-manifest
version=2
projectHash=2003ef30376fa13b
scope.0.id=chunk:src/app/profile_source.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=27
scope.0.semanticHash=b550a85b2a61df45
scope.1.id=function:_require_default_map:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=8
scope.1.semanticHash=848d7017c5d364b9
scope.2.id=function:_resolve_testing_bootstrap:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=16
scope.2.semanticHash=44287fd09cf3574c
scope.3.id=function:source.resolve_map:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=0791bb30129ad2bd
scope.4.id=function:source.resolve_bootstrap:22
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=f5767c04b6fc0c4c
]]
