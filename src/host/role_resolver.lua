local runtime_ports = require("src.foundation.ports.runtime_ports")

local role_resolver = {}

local function role_matches_predicate(role, predicate)
  if role == nil then
    return false
  end
  if predicate == nil then
    return true
  end
  return predicate(role) == true
end

local function _resolve_game_role(player_id)
  if GameAPI and type(GameAPI.get_role) == "function" then
    local ok, fallback = pcall(GameAPI.get_role, player_id)
    if ok then
      return fallback
    end
  end
  return nil
end

function role_resolver.resolve_role_with(player_id, predicate)
  local role = runtime_ports.resolve_role(player_id)
  if role_matches_predicate(role, predicate) then
    return role
  end
  role = _resolve_game_role(player_id)
  if role_matches_predicate(role, predicate) then
    return role
  end
  return nil
end

function role_resolver.resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    return roles
  end
  if GameAPI and type(GameAPI.get_all_valid_roles) == "function" then
    local ok, fallback = pcall(GameAPI.get_all_valid_roles)
    if ok and type(fallback) == "table" then
      return fallback
    end
  end
  return roles or {}
end

return role_resolver

--[[ mutate4lua-manifest
version=2
projectHash=b842894e59fe926a
scope.0.id=chunk:src/host/role_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=52
scope.0.semanticHash=19506ebabc16b630
scope.1.id=function:role_matches_predicate:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=13
scope.1.semanticHash=bb8f0efbe7ef11d2
scope.2.id=function:_resolve_game_role:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=23
scope.2.semanticHash=715bfe65b6c6f836
scope.3.id=function:role_resolver.resolve_role_with:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=35
scope.3.semanticHash=01ff34edb379885b
scope.4.id=function:role_resolver.resolve_roles:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=49
scope.4.semanticHash=c7453abff9591bd9
]]
