local building_effects = require("src.ui.BuildingEffects")
local tile_renderer = require("src.ui.TileRenderer")
local number_utils = require("src.core.NumberUtils")
local runtime_constants = require("Config.RuntimeConstants")
local vehicle_feature = require("src.game.vehicle.VehicleFeature")

local board_view = {}

local function _collect_tile_positions(tiles, tile_count)
  local positions = {}
  for i = 1, tile_count do
    local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
    assert(unit.get_position ~= nil, "missing tile get_position: " .. tostring(i))
    positions[i] = unit.get_position()
  end
  return positions
end

local function _render_board_tiles(board, tiles, tile_count)
  local board_tiles = assert(board.tile_states, "missing ui_model.board.tile_states")
  local tile_ids = {}
  for i, tile in ipairs(board.tiles) do
    assert(tile ~= nil and tile.id ~= nil, "missing tile id: " .. tostring(i))
    tile_ids[i] = tile.id
  end
  for i = 1, tile_count do
    local tile_id = assert(tile_ids[i], "missing tile_id: " .. tostring(i))
    local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
    local tile = assert(board.tiles[i], "missing board tile: " .. tostring(i))
    local tile_state = board_tiles[tile_id]
    if tile.type == "land" then
      assert(tile_state ~= nil, "missing board tile state: " .. tostring(tile_id))
    end
    local owner_id = tile_state and tile_state.owner_id or nil
    tile_renderer.render_tile(unit, tile_id, owner_id)
  end
end

local function _calc_tile_spacing(positions, tile_count)
  local spacing = 0
  local spacing_count = 0
  for i = 1, tile_count - 1 do
    local a = positions[i]
    local b = positions[i + 1]
    assert(a ~= nil and a.x ~= nil and a.y ~= nil and a.z ~= nil, "missing tile position: " .. tostring(i))
    assert(b ~= nil and b.x ~= nil and b.y ~= nil and b.z ~= nil, "missing tile position: " .. tostring(i + 1))
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    local dist = math.Vector3(dx, dy, dz):length()
    assert(dist ~= nil, "missing tile distance: " .. tostring(i))
    if dist > 0 then
      spacing = spacing + dist
      spacing_count = spacing_count + 1
    end
  end
  if spacing_count > 0 then
    return (spacing / spacing_count) * 0.28
  end
  return nil
end

local function _resolve_player_id(player, i)
  return assert(player.id, "missing player id: " .. tostring(i))
end

local function _log_ready(state, log_once, build_log_prefix, key, ...)
  log_once(state, "info", key, build_log_prefix(), ...)
end

local function _ensure_tile_anchors(state, board, scene, tile_count, log_once, build_log_prefix)
  if state.tile_positions and #state.tile_positions >= tile_count then
    return
  end

  assert(type(scene.tiles) == "table", "missing board_scene.tiles")
  assert(#scene.tiles >= tile_count, "insufficient board_scene.tiles")
  local tiles = scene.tiles

  local positions = _collect_tile_positions(tiles, tile_count)
  state.tile_units = tiles
  state.tile_positions = positions

  _render_board_tiles(board, tiles, tile_count)

  local spacing = _calc_tile_spacing(positions, tile_count)
  if spacing then
    state.tile_spacing = spacing
  end

  _log_ready(state, log_once, build_log_prefix, "tiles_ready", "tile anchors ready:", tostring(tile_count))
end

local function _each_player(players, fn)
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    fn(player, i)
  end
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

local function _ensure_player_units(state, players, log_once, build_log_prefix)
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
  _each_player(players, function(player, i)
    local pid = _resolve_player_id(player, i)
    local name = assert(player.name, "missing player name: " .. tostring(i))
    local unit = name_to_unit[name] or role_units[pid]
    assert(unit ~= nil, "missing player unit: " .. tostring(pid))
    mapped[pid] = unit
    mapped_count = mapped_count + 1
  end)

  state.player_units = mapped
  state.player_units_missing = false
  _log_ready(
    state,
    log_once,
    build_log_prefix,
    "player_units_ready",
    "player->unit mapped:",
    tostring(mapped_count),
    "(missing:",
    "0)"
  )
end

local function _resolve_active_player_base(state, player, i)
  local idx = assert(player.position, "missing player position: " .. tostring(i))
  assert(state.tile_positions ~= nil, "missing tile_positions")
  local base = assert(state.tile_positions[idx], "missing tile_position: " .. tostring(idx))
  local pid = _resolve_player_id(player, i)
  return idx, base, pid
end

local function _build_snapshot(players)
  local snapshot = {}
  _each_player(players, function(player, i)
    local pid = _resolve_player_id(player, i)
    local pos = player.position
    local eliminated = player.eliminated and 1 or 0
    snapshot[pid] = tostring(pos) .. ":" .. tostring(eliminated)
  end)
  return snapshot
end

local function _compute_need_sync(state, snapshot, vehicle_resync_seq)
  local need_sync = state.board_sync_pending or false
  local last_positions = assert(state.board_last_positions, "missing board_last_positions")
  if not need_sync then
    for pid, value in pairs(snapshot) do
      if last_positions[pid] ~= value then
        need_sync = true
        break
      end
    end
  end
  if not need_sync and state.board_last_vehicle_resync_seq ~= vehicle_resync_seq then
    need_sync = true
  end
  return need_sync
end

local function _build_occupants(state, players)
  local occupants = {}
  _each_player(players, function(player, i)
    if not player.eliminated then
      local idx, _, pid = _resolve_active_player_base(state, player, i)
      local list = occupants[idx]
      if not list then
        list = {}
        occupants[idx] = list
      end
      list[#list + 1] = pid
    end
  end)
  return occupants
end

local function _resolve_min_player_y(scene)
  assert(scene.ground ~= nil, "missing board_scene.ground")
  assert(scene.ground.get_position ~= nil, "missing board_scene.ground.get_position")
  local ground_pos = scene.ground.get_position()
  assert(ground_pos ~= nil and ground_pos.y ~= nil, "missing ground position")
  return ground_pos.y + 1.5
end

local function _resolve_occupant_slot(list, pid)
  local count = list and #list or 1
  local slot = 1
  if list and count > 1 then
    for s = 1, count do
      if list[s] == pid then
        slot = s
        break
      end
    end
  end
  return slot, count
end

local function _calc_slot_offset(slot, count, spacing)
  if count <= 1 or spacing <= 0 then
    return 0.0, 0.0
  end
  local per_row = 0
  while per_row * per_row < count do
    per_row = per_row + 1
  end
  local row = math.floor((slot - 1) / per_row)
  local col = (slot - 1) % per_row
  local start = -(per_row - 1) * spacing * 0.5
  local ox = start + col * spacing
  local oz = start + row * spacing
  return ox, oz
end

local function _place_players(state, players, occupants, spacing, min_player_y)
  _each_player(players, function(player, i)
    if not player.eliminated then
      local idx, base, pid = _resolve_active_player_base(state, player, i)
      assert(state.player_units ~= nil, "missing player_units")
      local unit = assert(state.player_units[pid], "missing player unit: " .. tostring(pid))
      local base_y = assert(base.y, "missing base.y: " .. tostring(idx))
      local y_offset = 0
      if base_y < min_player_y then
        y_offset = min_player_y - base_y
      end
      local list = occupants[idx]
      local slot, count = _resolve_occupant_slot(list, pid)
      local ox, oz = _calc_slot_offset(slot, count, spacing)
      local target_pos = base + math.Vector3(ox, y_offset, oz)
      local seat_id = vehicle_feature.resolve_seat_id(player.seat_id)
      if seat_id and vehicle_helper and vehicle_helper.forward_eca_event_set_position then
        vehicle_helper.forward_eca_event_set_position(pid, target_pos)
      else
        assert(unit.set_position ~= nil, "missing unit.set_position: " .. tostring(pid))
        unit.set_position(target_pos)
      end
    end
  end)
end

function board_view.refresh_board(state, ui_model, log_once, build_log_prefix)
  assert(ui_model ~= nil, "missing ui_model")
  local board = assert(ui_model.board, "missing ui_model.board")
  local players = assert(board.players, "missing ui_model.board.players")
  assert(board.tiles ~= nil, "missing ui_model.board.tiles")
  local tile_count = board.tile_count or #board.tiles
  assert(tile_count > 0, "missing tile_count")
  assert(log_once ~= nil, "missing log_once")
  assert(build_log_prefix ~= nil, "missing build_log_prefix")
  local scene = assert(state.board_scene, "missing board_scene")

  _ensure_tile_anchors(state, board, scene, tile_count, log_once, build_log_prefix)
  _ensure_player_units(state, players, log_once, build_log_prefix)

  local phase = board.phase
  local anim = board.move_anim
  local suppress_sync = phase == "wait_move_anim" and anim
  local vehicle_resync_seq = board.vehicle_resync_seq or 0

  local snapshot = _build_snapshot(players)
  local need_sync = _compute_need_sync(state, snapshot, vehicle_resync_seq)

  if suppress_sync then
    state.board_sync_pending = true
  end

  if suppress_sync or not need_sync then
    state.board_last_positions = snapshot
    state.board_last_vehicle_resync_seq = vehicle_resync_seq
    return
  end

  local occupants = _build_occupants(state, players)
  local spacing = state.tile_spacing or 0
  local min_player_y = _resolve_min_player_y(scene)
  _place_players(state, players, occupants, spacing, min_player_y)

  state.board_sync_pending = false
  state.board_last_positions = snapshot
  state.board_last_vehicle_resync_seq = vehicle_resync_seq
end

function board_view.on_tile_upgraded(state, tile_id, level)
  assert(tile_id ~= nil, "missing tile_id")
  assert(level ~= nil, "missing level")
  local scene = assert(state.board_scene, "missing board_scene")
  local buildings = assert(scene.buildings, "missing board_scene.buildings")
  local board = assert(state.game and state.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(buildings[idx] ~= nil, "missing building unit: " .. tostring(idx))
  local lv = assert(number_utils.to_integer(level), "invalid level: " .. tostring(level))
  assert(lv >= 1 and lv <= 3, "invalid level: " .. tostring(lv))
  local root_quaternion = assert(runtime_constants.q_zero, "missing Q_ZERO")
  building_effects.spawn_upgrade_building_units(scene, root_quaternion, idx, lv)
end

function board_view.on_tile_owner_changed(state, tile_id, owner_id)
  assert(tile_id ~= nil, "missing tile_id")
  local board = assert(state.game and state.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(state.tile_units ~= nil, "missing tile_units")
  assert(state.tile_units[idx] ~= nil, "missing tile unit: " .. tostring(idx))
  tile_renderer.render_tile(state.tile_units[idx], tile_id, owner_id)
end

return board_view
