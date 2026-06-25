local runtime_assets = require("src.config.runtime_assets")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_id_utils = require("src.foundation.identity")
local logger = require("src.foundation.log")

local M = {}

local function _resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    return roles
  end
  local retried = runtime_ports.resolve_roles()
  if type(retried) == "table" and #retried > 0 then
    logger.info("[Eggy]", "角色列表二次拉取成功，角色数量:", tostring(#retried))
    return retried
  end
  return {}
end

local function _pick_synthetic_unit_keys(count)
  local selected = {}
  if count == nil or count <= 0 then
    return selected
  end
  local pool = {}
  for index, unit_key in ipairs(runtime_assets.synthetic_ai_unit_key_pool()) do
    pool[index] = unit_key
  end
  local limit = count
  if limit > #pool then
    limit = #pool
  end
  for index = 1, limit do
    local pick_index = GameAPI.random_int(index, #pool)
    local picked = pool[pick_index]
    pool[pick_index] = pool[index]
    pool[index] = picked
    selected[index] = pool[index]
  end
  return selected
end

local function _resolve_role_id_from_role(role)
  if not (role and role.get_roleid) then
    return nil
  end
  local ok, id = pcall(role.get_roleid)
  if not ok or id == nil then
    return nil
  end
  return role_id_utils.normalize(id)
end

local function _resolve_role_name(role)
  if not role.get_name then
    return nil
  end
  local ok, name = pcall(role.get_name)
  if not ok or not name or name == "" then
    return nil
  end
  return name
end

local function _add_real_roles_to_roster(roster, roles, max_players)
  for _, role in ipairs(roles) do
    local role_id = _resolve_role_id_from_role(role)
    if role_id ~= nil then
      local role_name = _resolve_role_name(role)
      roster[#roster + 1] = { role_id = role_id, name = role_name }
    end
    if max_players and #roster >= max_players then
      break
    end
  end
  return roster
end

local function _build_synthetic_role(slot_index, unit_key)
  local profile = runtime_assets.synthetic_ai_profile(slot_index, {
    unit_key = unit_key,
  })
  return {
    role_id = -slot_index,
    name = profile.name,
    synthetic = true,
    unit_key = profile.unit_key,
    avatar_image_key = profile.avatar_image_key,
  }
end

local function _add_synthetic_roles_to_roster(roster, max_players, selected_unit_keys)
  local missing_count = max_players and (max_players - #roster) or 0
  for index = 1, missing_count do
    local slot_index = #roster + 1
    roster[slot_index] = _build_synthetic_role(slot_index, selected_unit_keys[index])
  end
  return roster
end

local function _warn_if_roles_truncated(roles_count, max_players)
  if max_players and roles_count > max_players then
    logger.warn(
      "[Eggy]",
      "角色数量超过上限，已截断:",
      tostring(roles_count),
      "->",
      tostring(max_players)
    )
  end
end

function M.build_startup_roster(max_players)
  local roster = {}
  local roles = _resolve_roles()
  roster = _add_real_roles_to_roster(roster, roles, max_players)
  local missing_count = max_players and (max_players - #roster) or 0
  local selected_unit_keys = _pick_synthetic_unit_keys(missing_count)
  roster = _add_synthetic_roles_to_roster(roster, max_players, selected_unit_keys)
  _warn_if_roles_truncated(#roles, max_players)
  return roster
end

function M.build_startup_ai_map(role_roster)
  local ai = nil
  for _, role in ipairs(role_roster or {}) do
    if role and role.synthetic == true then
      if ai == nil then
        ai = {}
      end
      ai[role.role_id] = true
    end
  end
  return ai
end

function M.build_synthetic_player_specs(role_roster)
  local specs = {}
  for _, role in ipairs(role_roster or {}) do
    if role and role.synthetic == true then
      specs[#specs + 1] = {
        player_id = role.role_id,
        name = role.name,
        unit_key = role.unit_key,
        avatar_image_key = role.avatar_image_key,
      }
    end
  end
  return specs
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=5a956ef9772132de
scope.0.id=chunk:src/app/roster_roles.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=154
scope.0.semanticHash=d02068e5835c526d
scope.1.id=function:_resolve_roles:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=19
scope.1.semanticHash=03c325872a09863b
scope.2.id=function:_resolve_role_id_from_role:44
scope.2.kind=function
scope.2.startLine=44
scope.2.endLine=53
scope.2.semanticHash=72691274297ca755
scope.3.id=function:_resolve_role_name:55
scope.3.kind=function
scope.3.startLine=55
scope.3.endLine=64
scope.3.semanticHash=f6fb9c5baf5759b1
scope.4.id=function:_build_synthetic_role:80
scope.4.kind=function
scope.4.startLine=80
scope.4.endLine=91
scope.4.semanticHash=56981974bbe67fdf
scope.5.id=function:_warn_if_roles_truncated:102
scope.5.kind=function
scope.5.startLine=102
scope.5.endLine=112
scope.5.semanticHash=bec44c9209eabe17
scope.6.id=function:M.build_startup_roster:114
scope.6.kind=function
scope.6.startLine=114
scope.6.endLine=123
scope.6.semanticHash=1abce8f0a5951d9f
]]
