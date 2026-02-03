local building_effects = require("src.ui.BuildingEffects")
local tile_renderer = require("src.ui.TileRenderer")

local eggy_layer_board = {}

function eggy_layer_board.refresh_board(state, ui_model, log_once, build_log_prefix)
  assert(ui_model ~= nil, "missing ui_model")
  local board = assert(ui_model.board, "missing ui_model.board")
  local players = assert(board.players, "missing ui_model.board.players")
  assert(board.tiles ~= nil, "missing ui_model.board.tiles")
  local tile_count = board.tile_count or #board.tiles
  assert(tile_count > 0, "missing tile_count")
  assert(log_once ~= nil, "missing log_once")
  assert(build_log_prefix ~= nil, "missing build_log_prefix")
  local scene = assert(state.board_scene, "missing board_scene")

  if not state.tile_positions or #state.tile_positions < tile_count then
    assert(type(scene.tiles) == "table", "missing board_scene.tiles")
    assert(#scene.tiles >= tile_count, "insufficient board_scene.tiles")
    local tiles = scene.tiles

    local positions = {}
    for i = 1, tile_count do
      local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
      assert(unit.get_position ~= nil, "missing tile get_position: " .. tostring(i))
      positions[i] = unit.get_position()
    end

    state.tile_units = tiles
    state.tile_positions = positions

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
      state.tile_spacing = (spacing / spacing_count) * 0.28
    end

    log_once(state, "info", "tiles_ready", build_log_prefix(), "tile anchors ready:", tostring(tile_count))
  end

  if not state.player_units or state.player_units_missing then
    local roles = assert(all_roles, "missing ALLROLES")
    local name_to_unit = {}
    local role_units = {}
    for i, role in ipairs(roles) do
      assert(role ~= nil, "missing role: " .. tostring(i))
      assert(role.get_ctrl_unit ~= nil, "missing role.get_ctrl_unit: " .. tostring(i))
      local unit = role.get_ctrl_unit()
      role_units[i] = unit
      assert(role.get_name ~= nil, "missing role.get_name: " .. tostring(i))
      local name = assert(role.get_name(), "missing role name: " .. tostring(i))
      name_to_unit[name] = unit
    end

    local mapped = {}
    local mapped_count = 0
    for i, player in ipairs(players) do
      assert(player ~= nil, "missing player: " .. tostring(i))
      local pid = assert(player.id, "missing player id: " .. tostring(i))
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

  local phase = board.phase
  local anim = board.move_anim
  local suppress_sync = phase == "wait_move_anim" and anim

  local snapshot = {}
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    local pid = assert(player.id, "missing player id: " .. tostring(i))
    local pos = player.position
    local eliminated = player.eliminated and 1 or 0
    snapshot[pid] = tostring(pos) .. ":" .. tostring(eliminated)
  end

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

  if suppress_sync then
    state.board_sync_pending = true
  end

  if suppress_sync or not need_sync then
    state.board_last_positions = snapshot
    return
  end

  local occupants = {}
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      local idx = assert(player.position, "missing player position: " .. tostring(i))
      assert(state.tile_positions ~= nil, "missing tile_positions")
      assert(state.tile_positions[idx] ~= nil, "missing tile_position: " .. tostring(idx))
      local pid = assert(player.id, "missing player id: " .. tostring(i))
      local list = occupants[idx]
      if not list then
        list = {}
        occupants[idx] = list
      end
      list[#list + 1] = pid
    end
  end

  local spacing = state.tile_spacing or 0
  assert(scene.ground ~= nil, "missing board_scene.ground")
  assert(scene.ground.get_position ~= nil, "missing board_scene.ground.get_position")
  local ground_pos = scene.ground.get_position()
  assert(ground_pos ~= nil and ground_pos.y ~= nil, "missing ground position")
  local ground_y = ground_pos.y
  local min_player_y = ground_y + 1.5
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      local idx = assert(player.position, "missing player position: " .. tostring(i))
      assert(state.tile_positions ~= nil, "missing tile_positions")
      local base = assert(state.tile_positions[idx], "missing tile_position: " .. tostring(idx))
      local pid = assert(player.id, "missing player id: " .. tostring(i))
      assert(state.player_units ~= nil, "missing player_units")
      local unit = assert(state.player_units[pid], "missing player unit: " .. tostring(pid))
      assert(unit.set_position ~= nil, "missing unit.set_position: " .. tostring(pid))
      local base_y = assert(base.y, "missing base.y: " .. tostring(idx))
      local y_offset = 0
      if base_y < min_player_y then
        y_offset = min_player_y - base_y
      end
      local list = occupants[idx]
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
      if count > 1 and spacing > 0 then
        local per_row = 0
        while per_row * per_row < count do
          per_row = per_row + 1
        end
        local row = math.floor((slot - 1) / per_row)
        local col = (slot - 1) % per_row
        local start = -(per_row - 1) * spacing * 0.5
        local ox = start + col * spacing
        local oz = start + row * spacing
        unit.set_position(base + math.Vector3(ox, y_offset, oz))
      else
        unit.set_position(base + math.Vector3(0.0, y_offset, 0.0))
      end
    end
  end

  state.board_sync_pending = false
  state.board_last_positions = snapshot
end

function eggy_layer_board.on_tile_upgraded(state, tile_id, level)
  assert(tile_id ~= nil, "missing tile_id")
  assert(level ~= nil, "missing level")
  local scene = assert(state.board_scene, "missing board_scene")
  local buildings = assert(scene.buildings, "missing board_scene.buildings")
  local board = assert(state.game and state.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(buildings[idx] ~= nil, "missing building unit: " .. tostring(idx))
  local lv = assert(tonumber(level), "invalid level: " .. tostring(level))
  assert(lv >= 1 and lv <= 3, "invalid level: " .. tostring(lv))
  local root_quaternion = assert(q_zero, "missing Q_ZERO")
  building_effects.spawn_upgrade_building_units(scene, root_quaternion, idx, lv)
end

function eggy_layer_board.on_tile_owner_changed(state, tile_id, owner_id)
  assert(tile_id ~= nil, "missing tile_id")
  local board = assert(state.game and state.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(state.tile_units ~= nil, "missing tile_units")
  assert(state.tile_units[idx] ~= nil, "missing tile unit: " .. tostring(idx))
  tile_renderer.render_tile(state.tile_units[idx], tile_id, owner_id)
end

return eggy_layer_board
