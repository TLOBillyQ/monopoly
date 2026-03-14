local M = {}
local runtime_ports = require("src.core.ports.runtime_ports")
local role_id_utils = require("src.core.utils.role_id")

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

local function _resolve_roles_from_players(players)
  local roles = {}
  for _, player in ipairs(players or {}) do
    if player and player.id ~= nil then
      local role = runtime_ports.resolve_role(player.id)
      if role ~= nil then
        roles[#roles + 1] = role
      end
    end
  end
  return roles
end

local function _build_role_units(roles)
  local name_to_unit = {}
  local role_units = {}
  for i, role in ipairs(roles) do
    assert(role ~= nil, "missing role: " .. tostring(i))
    assert(role.get_ctrl_unit ~= nil, "missing role.get_ctrl_unit: " .. tostring(i))
    local unit = role.get_ctrl_unit()
    local role_id = _resolve_role_id(role, i)
    role_units[role_id] = unit
    if role.get_name ~= nil then
      local name = role.get_name()
      if name ~= nil and name ~= "" then
        name_to_unit[name] = unit
      end
    end
  end
  return name_to_unit, role_units
end

function M.ensure_player_units(state, players, log_once, build_log_prefix)
  if state.player_units and not state.player_units_missing then
    return
  end

  local roles = runtime_ports.resolve_roles()
  if type(roles) ~= "table" or #roles == 0 then
    roles = _resolve_roles_from_players(players)
  end
  assert(type(roles) == "table" and #roles > 0, "missing runtime roles")
  local name_to_unit, role_units = _build_role_units(roles)

  local mapped = {}
  local mapped_count = 0
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    local pid = _resolve_player_id(player, i)
    local name = assert(player.name, "missing player name: " .. tostring(i))
    local unit = name_to_unit[name] or role_units[pid]
    if unit == nil then
      local role = runtime_ports.resolve_role(pid)
      if role and type(role.get_ctrl_unit) == "function" then
        unit = role.get_ctrl_unit()
      end
    end
    assert(unit ~= nil, "missing player unit: " .. tostring(pid))
    mapped[pid] = unit
    mapped_count = mapped_count + 1
  end

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
