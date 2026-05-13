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

function role_resolver.resolve_game_role(player_id)
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
  role = role_resolver.resolve_game_role(player_id)
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
