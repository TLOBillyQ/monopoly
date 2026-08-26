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

local function _unit_key_pool()
  local pool = {}
  for index, unit_key in ipairs(runtime_assets.synthetic_ai_unit_key_pool()) do
    pool[index] = unit_key
  end
  return pool
end

local function _clamp_limit(count, pool)
  local limit = count
  if limit > #pool then
    limit = #pool
  end
  return limit
end

-- Fisher-Yates 单步:把 index 处与随机位交换,返回交换后的 index 位值。
local function _shuffle_pick(pool, index)
  local pick_index = GameAPI.random_int(index, #pool)
  local picked = pool[pick_index]
  pool[pick_index] = pool[index]
  pool[index] = picked
  return pool[index]
end

local function _pick_synthetic_unit_keys(count)
  local selected = {}
  if count == nil or count <= 0 then
    return selected
  end
  local pool = _unit_key_pool()
  local limit = _clamp_limit(count, pool)
  for index = 1, limit do
    selected[index] = _shuffle_pick(pool, index)
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
      roster[#roster + 1] = { role_id = role_id, name = role_name, role = role }
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

local function _synthetic_roles(role_roster)
  local acc = {}
  for _, role in ipairs(role_roster or {}) do
    if role and role.synthetic == true then
      acc[#acc + 1] = role
    end
  end
  return acc
end

function M.build_startup_ai_map(role_roster)
  local ai = nil
  for _, role in ipairs(_synthetic_roles(role_roster)) do
    if ai == nil then
      ai = {}
    end
    ai[role.role_id] = true
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
version=4
projectHash=8ff9a8b31fd5127e
scope.0.id=chunk:src/app/roster_roles.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=177
scope.0.semanticHash=3736fa62b844e314
scope.1.id=function:_resolve_roles
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=19
scope.1.semanticHash=1cceed690fc2f4ed
scope.2.id=function:_unit_key_pool
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=27
scope.2.semanticHash=1ae5774db88dc4df
scope.3.id=function:_clamp_limit
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=35
scope.3.semanticHash=5206547ae2d911a8
scope.4.id=function:_shuffle_pick
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=44
scope.4.semanticHash=cc1b481c60aa148f
scope.5.id=function:_pick_synthetic_unit_keys
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=57
scope.5.semanticHash=d3ac999712000eda
scope.6.id=function:_resolve_role_id_from_role
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=68
scope.6.semanticHash=9390873b2cf48cf8
scope.7.id=function:_resolve_role_name
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=79
scope.7.semanticHash=9b7da075514239af
scope.8.id=function:_add_real_roles_to_roster
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=93
scope.8.semanticHash=56dd947093ab7b4a
scope.9.id=function:_build_synthetic_role
scope.9.kind=function
scope.9.startLine=95
scope.9.endLine=106
scope.9.semanticHash=c1797d4b47033e6f
scope.10.id=function:_add_synthetic_roles_to_roster
scope.10.kind=function
scope.10.startLine=108
scope.10.endLine=115
scope.10.semanticHash=5594c363070061d6
scope.11.id=function:_warn_if_roles_truncated
scope.11.kind=function
scope.11.startLine=117
scope.11.endLine=127
scope.11.semanticHash=f5eec7fb51e3eb08
scope.12.id=function:M.build_startup_roster
scope.12.kind=function
scope.12.startLine=129
scope.12.endLine=138
scope.12.semanticHash=13c95fdc646fcf36
scope.13.id=function:_synthetic_roles
scope.13.kind=function
scope.13.startLine=140
scope.13.endLine=148
scope.13.semanticHash=1f3b6fa30e518860
scope.14.id=function:M.build_startup_ai_map
scope.14.kind=function
scope.14.startLine=150
scope.14.endLine=159
scope.14.semanticHash=fc05717216f5962f
scope.15.id=function:M.build_synthetic_player_specs
scope.15.kind=function
scope.15.startLine=161
scope.15.endLine=174
scope.15.semanticHash=5e540d5d0b17f32e
]]
