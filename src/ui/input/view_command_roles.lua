local number_utils = require("src.foundation.number")
local host_runtime_ports = require("src.ui.host_bridge")

local roles = {}

local function _resolve_role_from_runtime(runtime, normalized)
  if host_runtime_ports and type(host_runtime_ports.resolve_roles) == "function" and runtime and type(runtime.resolve_role_id) == "function" then
    for _, role in ipairs(host_runtime_ports.resolve_roles() or {}) do
      if tostring(runtime.resolve_role_id(role)) == tostring(normalized) then
        return role
      end
    end
  end
  return nil
end

local function _resolve_role_from_host(normalized)
  if host_runtime_ports and type(host_runtime_ports.resolve_role_with) == "function" then
    local resolved = host_runtime_ports.resolve_role_with(normalized)
    if resolved ~= nil then
      return resolved
    end
  end
  return nil
end

local function _resolve_role_from_game_api(normalized)
  local game_api = _G.GameAPI
  if game_api and type(game_api.get_role) == "function" then
    local resolved = game_api.get_role(normalized)
    local normalized_int = number_utils.to_integer(normalized)
    if resolved == nil and normalized_int ~= nil then
      resolved = game_api.get_role(normalized_int)
    end
    if resolved ~= nil then
      return resolved
    end
  end
  return nil
end

local function _fallback_role(normalized)
  return {
    get_roleid = function()
      return normalized
    end,
  }
end

function roles.resolve(runtime, role_id)
  local normalized = role_id
  return _resolve_role_from_runtime(runtime, normalized)
    or _resolve_role_from_host(normalized)
    or _resolve_role_from_game_api(normalized)
    or _fallback_role(normalized)
end

return roles

--[[ mutate4lua-manifest
version=2
projectHash=3bea74f5d6a57567
scope.0.id=chunk:src/ui/input/view_command_roles.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=59
scope.0.semanticHash=b638d172f797548a
scope.0.lastMutatedAt=2026-06-05T07:28:10Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=15
scope.0.lastMutationKilled=15
scope.1.id=function:_resolve_role_from_host:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=25
scope.1.semanticHash=4ae9b60695dc705b
scope.1.lastMutatedAt=2026-06-05T07:28:10Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_resolve_role_from_game_api:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=40
scope.2.semanticHash=400e29bab9a52679
scope.2.lastMutatedAt=2026-06-05T07:28:10Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=11
scope.2.lastMutationKilled=11
scope.3.id=function:anonymous@44:44
scope.3.kind=function
scope.3.startLine=44
scope.3.endLine=46
scope.3.semanticHash=c06cb8f90f07e1f0
scope.4.id=function:_fallback_role:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=48
scope.4.semanticHash=2db49b8f76cb9648
scope.5.id=function:roles.resolve:50
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=56
scope.5.semanticHash=22ea459a70bf9e57
scope.5.lastMutatedAt=2026-06-05T07:28:10Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=7
]]
