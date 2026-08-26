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

local function _has_roles(roles)
  return type(roles) == "table" and #roles > 0
end

local function _game_roles_fallback()
  if GameAPI and type(GameAPI.get_all_valid_roles) == "function" then
    local ok, fallback = pcall(GameAPI.get_all_valid_roles)
    if ok and type(fallback) == "table" then
      return fallback
    end
  end
  return nil
end

function role_resolver.resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if _has_roles(roles) then
    return roles
  end
  return _game_roles_fallback() or roles or {}
end

return role_resolver

--[[ mutate4lua-manifest
version=4
projectHash=e298748d16082882
scope.0.id=chunk:src/host/role_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=60
scope.0.semanticHash=585c9878153a9288
scope.1.id=function:role_matches_predicate
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=13
scope.1.semanticHash=2c1f43df3e6729d8
scope.2.id=function:_resolve_game_role
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=23
scope.2.semanticHash=fb9b9a01b8e60dd4
scope.3.id=function:role_resolver.resolve_role_with
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=35
scope.3.semanticHash=806767850a95b2a6
scope.4.id=function:_has_roles
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=99d5f926c9946ecf
scope.5.id=function:_game_roles_fallback
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=49
scope.5.semanticHash=f07c5e391e199702
scope.6.id=function:role_resolver.resolve_roles
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=57
scope.6.semanticHash=67595fe5bb699760
]]
