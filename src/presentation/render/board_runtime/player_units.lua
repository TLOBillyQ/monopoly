local M = {}

local function _resolve_player_id(player, i)
  return assert(player.id, "missing player id: " .. tostring(i))
end

local function _resolve_role_id(role, fallback)
  if role and role.get_roleid then
    local ok, role_id = pcall(role.get_roleid)
    if ok and role_id ~= nil then
      return role_id
    end
  end
  return fallback
end

local function _resolve_roles_from_players(players)
  local roles = {}
  if not (GameAPI and GameAPI.get_role) then
    return roles
  end
  for _, player in ipairs(players or {}) do
    if player and player.id ~= nil then
      local ok, role = pcall(GameAPI.get_role, player.id)
      if ok and role ~= nil then
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
    assert(role.get_name ~= nil, "missing role.get_name: " .. tostring(i))
    local name = assert(role.get_name(), "missing role name: " .. tostring(i))
    name_to_unit[name] = unit
  end
  return name_to_unit, role_units
end

function M.ensure_player_units(state, players, log_once, build_log_prefix)
  if state.player_units and not state.player_units_missing then
    return
  end

  local roles = all_roles
  if type(roles) ~= "table" or #roles == 0 then
    roles = _resolve_roles_from_players(players)
  end
  assert(type(roles) == "table" and #roles > 0, "missing ALLROLES")
  local name_to_unit, role_units = _build_role_units(roles)

  local mapped = {}
  local mapped_count = 0
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    local pid = _resolve_player_id(player, i)
    local name = assert(player.name, "missing player name: " .. tostring(i))
    local unit = name_to_unit[name] or role_units[pid]
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
