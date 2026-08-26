local M = {}
local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_id_utils = require("src.foundation.identity")

local function _resolve_player_id(player, i)
  return assert(role_id_utils.normalize(player.id), "missing player id: " .. tostring(i))
end

local function _resolve_role_id(role, fallback)
  if role and role.get_roleid then
    local ok, role_id = pcall(role.get_roleid)
    if ok and role_id ~= nil then
      return role_id_utils.normalize(role_id)
    end
  end
  return role_id_utils.normalize(fallback)
end

local function _append_role(roles, player)
  if not (player and player.id ~= nil) then
    return
  end
  local role = runtime_ports.resolve_role(player.id)
  if role ~= nil then
    roles[#roles + 1] = role
  end
end

local function _resolve_roles_from_players(players)
  local roles = {}
  for _, player in ipairs(players or {}) do
    _append_role(roles, player)
  end
  return roles
end

local function _index_role_unit(name_to_unit, role_units, role, i)
  assert(role ~= nil, "missing role: " .. tostring(i))
  assert(role.get_ctrl_unit ~= nil, "missing role.get_ctrl_unit: " .. tostring(i))
  local unit = role.get_ctrl_unit()
  local role_id = assert(_resolve_role_id(role, i), "missing role_id: " .. tostring(i))
  role_units[role_id] = unit
  if role.get_name ~= nil then
    local name = role.get_name()
    if name ~= nil and name ~= "" then
      name_to_unit[name] = unit
    end
  end
end

local function _build_role_units(roles)
  local name_to_unit = {}
  local role_units = {}
  for i, role in ipairs(roles) do
    _index_role_unit(name_to_unit, role_units, role, i)
  end
  return name_to_unit, role_units
end

local function _resolve_available_roles(players)
  local roles = runtime_ports.resolve_roles()
  if type(roles) ~= "table" or #roles == 0 then
    roles = _resolve_roles_from_players(players)
  end
  assert(type(roles) == "table" and #roles > 0, "missing runtime roles")
  return roles
end

local function _resolve_unit_from_role_port(pid)
  local unit = nil
  local role = runtime_ports.resolve_role(pid)
  if role and type(role.get_ctrl_unit) == "function" then
    unit = role.get_ctrl_unit()
  end
  assert(unit ~= nil, "missing player unit: " .. tostring(pid))
  return unit
end

local function _resolve_unit_for_player(name_to_unit, role_units, player, i)
  assert(player ~= nil, "missing player: " .. tostring(i))
  local pid = _resolve_player_id(player, i)
  local name = assert(player.name, "missing player name: " .. tostring(i))
  local unit = name_to_unit[name] or role_units[pid]
  if unit ~= nil then
    return pid, unit
  end
  return pid, _resolve_unit_from_role_port(pid)
end

local function _map_players_to_units(players, name_to_unit, role_units)
  local mapped = {}
  local mapped_count = 0
  for i, player in ipairs(players) do
    local pid, unit = _resolve_unit_for_player(name_to_unit, role_units, player, i)
    mapped[pid] = unit
    mapped_count = mapped_count + 1
  end
  return mapped, mapped_count
end

function M.ensure_player_units(state, players, log_once, build_log_prefix)
  if state.player_units and not state.player_units_missing then
    return
  end

  local roles = _resolve_available_roles(players)
  local name_to_unit, role_units = _build_role_units(roles)
  local mapped, mapped_count = _map_players_to_units(players, name_to_unit, role_units)

  state.player_units = mapped
  state.player_units_missing = false
  log_once(
    state,
    "info",
    "player_units_ready",
    build_log_prefix(),
    "player->unit mapped:",
    tostring(mapped_count),
    "(missing:",
    "0)"
  )
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=db526df39c2c31a7
scope.0.id=chunk:src/ui/render/board/player_units.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=125
scope.0.semanticHash=88a023d353b95aea
scope.1.id=function:_resolve_player_id
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=84d978942d95e365
scope.2.id=function:_resolve_role_id
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=17
scope.2.semanticHash=b66e80cfb90baea9
scope.3.id=function:_append_role
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=27
scope.3.semanticHash=dcce9ebaf77745a4
scope.4.id=function:_resolve_roles_from_players
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=35
scope.4.semanticHash=8cea00c493eb20e7
scope.5.id=function:_index_role_unit
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=49
scope.5.semanticHash=9d8ce13d6d02dfd8
scope.6.id=function:_build_role_units
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=58
scope.6.semanticHash=1b53bf19bf4c58f3
scope.7.id=function:_resolve_available_roles
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=67
scope.7.semanticHash=fcbe4a7a627683bc
scope.8.id=function:_resolve_unit_from_role_port
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=77
scope.8.semanticHash=c0b2821adebcdef4
scope.9.id=function:_resolve_unit_for_player
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=88
scope.9.semanticHash=c5e8a1025ed812ac
scope.10.id=function:_map_players_to_units
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=99
scope.10.semanticHash=dd6cb131e586aac2
scope.11.id=function:M.ensure_player_units
scope.11.kind=function
scope.11.startLine=101
scope.11.endLine=122
scope.11.semanticHash=6bfdc75f9ac59416
]]
