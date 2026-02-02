local BuildingEffects = require("Manager.BoardManager.GUI.BuildingEffects")
local TileRenderer = require("Manager.BoardManager.GUI.TileRenderer")

local EggyLayerBoard = {}

function EggyLayerBoard.refresh_board(layer, view, log_once, build_log_prefix)
  assert(view ~= nil, "missing view")
  assert(view.state ~= nil, "missing view.state")
  local players = assert(view.state.players, "missing view.state.players")
  assert(view.board ~= nil, "missing view.board")
  assert(view.board.tiles ~= nil, "missing view.board.tiles")
  local tile_count = view.board_tile_count or #view.board.tiles
  assert(tile_count > 0, "missing tile_count")
  assert(log_once ~= nil, "missing log_once")
  assert(build_log_prefix ~= nil, "missing build_log_prefix")

  if not layer.tile_positions or #layer.tile_positions < tile_count then
    assert(G ~= nil, "missing G")
    assert(type(G.tiles) == "table", "missing G.tiles")
    assert(#G.tiles >= tile_count, "insufficient G.tiles")
    local tiles = G.tiles

    local positions = {}
    for i = 1, tile_count do
      local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
      assert(unit.get_position ~= nil, "missing tile get_position: " .. tostring(i))
      positions[i] = unit.get_position()
    end

    layer.tile_units = tiles
    layer.tile_positions = positions

    assert(view.state.board ~= nil, "missing view.state.board")
    local board_tiles = assert(view.state.board.tiles, "missing view.state.board.tiles")
    local tile_ids = {}
    for i, tile in ipairs(view.board.tiles) do
      assert(tile ~= nil and tile.id ~= nil, "missing tile id: " .. tostring(i))
      tile_ids[i] = tile.id
    end
    for i = 1, tile_count do
      local tile_id = assert(tile_ids[i], "missing tile_id: " .. tostring(i))
      local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
      local tile_state = board_tiles[tile_id]
      assert(tile_state ~= nil, "missing board tile state: " .. tostring(tile_id))
      local owner_id = tile_state.owner_id
      TileRenderer.render_tile(unit, tile_id, owner_id)
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
      layer.tile_spacing = (spacing / spacing_count) * 0.28
    end

    log_once(layer, "info", "tiles_ready", build_log_prefix(), "tile anchors ready:", tostring(tile_count))
  end

  if not layer.player_units or layer.player_units_missing then
    local roles = assert(ALLROLES, "missing ALLROLES")
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

    layer.player_units = mapped
    layer.player_units_missing = false
    log_once(
      layer,
      "info",
      "player_units_ready",
      build_log_prefix(),
      "player->unit mapped:",
      tostring(mapped_count),
      "(missing:",
      "0)"
    )
  end

  local game = assert(layer.game, "missing game")
  local store = assert(game.store, "missing game.store")
  local phase = store:get({ "turn", "phase" })
  local anim = store:get({ "turn", "move_anim" })
  local suppress_sync = phase == "wait_move_anim" and anim

  local snapshot = {}
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    local pid = assert(player.id, "missing player id: " .. tostring(i))
    local pos = player.position
    local eliminated = player.eliminated and 1 or 0
    snapshot[pid] = tostring(pos) .. ":" .. tostring(eliminated)
  end

  local need_sync = layer.board_sync_pending or false
  local last_positions = assert(layer.board_last_positions, "missing board_last_positions")
  if not need_sync then
    for pid, value in pairs(snapshot) do
      if last_positions[pid] ~= value then
        need_sync = true
        break
      end
    end
  end

  if suppress_sync then
    layer.board_sync_pending = true
  end

  if suppress_sync or not need_sync then
    layer.board_last_positions = snapshot
    return
  end

  local occupants = {}
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      local idx = assert(player.position, "missing player position: " .. tostring(i))
      assert(layer.tile_positions ~= nil, "missing tile_positions")
      assert(layer.tile_positions[idx] ~= nil, "missing tile_position: " .. tostring(idx))
      local pid = assert(player.id, "missing player id: " .. tostring(i))
      local list = occupants[idx]
      if not list then
        list = {}
        occupants[idx] = list
      end
      list[#list + 1] = pid
    end
  end

  local spacing = layer.tile_spacing or 0
  assert(G ~= nil, "missing G")
  assert(G.ground ~= nil, "missing G.ground")
  assert(G.ground.get_position ~= nil, "missing G.ground.get_position")
  local ground_pos = G.ground.get_position()
  assert(ground_pos ~= nil and ground_pos.y ~= nil, "missing ground position")
  local ground_y = ground_pos.y
  local min_player_y = ground_y + 1.5
  for i, player in ipairs(players) do
    assert(player ~= nil, "missing player: " .. tostring(i))
    if not player.eliminated then
      local idx = assert(player.position, "missing player position: " .. tostring(i))
      assert(layer.tile_positions ~= nil, "missing tile_positions")
      local base = assert(layer.tile_positions[idx], "missing tile_position: " .. tostring(idx))
      local pid = assert(player.id, "missing player id: " .. tostring(i))
      assert(layer.player_units ~= nil, "missing player_units")
      local unit = assert(layer.player_units[pid], "missing player unit: " .. tostring(pid))
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

  layer.board_sync_pending = false
  layer.board_last_positions = snapshot
end

function EggyLayerBoard.on_tile_upgraded(layer, tile_id, level)
  assert(tile_id ~= nil, "missing tile_id")
  assert(level ~= nil, "missing level")
  assert(G ~= nil and G.buildings ~= nil, "missing G.buildings")
  local board = assert(layer.game and layer.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(G.buildings[idx] ~= nil, "missing building unit: " .. tostring(idx))
  local lv = assert(tonumber(level), "invalid level: " .. tostring(level))
  assert(lv >= 1 and lv <= 3, "invalid level: " .. tostring(lv))
  local root_quaternion = assert(Q_ZERO, "missing Q_ZERO")
  BuildingEffects.spawn_upgrade_building_units(root_quaternion, idx, lv)
end

function EggyLayerBoard.on_tile_owner_changed(layer, tile_id, owner_id)
  assert(tile_id ~= nil, "missing tile_id")
  local board = assert(layer.game and layer.game.board, "missing board")
  assert(board.index_of_tile_id ~= nil, "missing board.index_of_tile_id")
  local idx = assert(board:index_of_tile_id(tile_id), "missing tile index: " .. tostring(tile_id))
  assert(layer.tile_units ~= nil, "missing tile_units")
  assert(layer.tile_units[idx] ~= nil, "missing tile unit: " .. tostring(idx))
  TileRenderer.render_tile(layer.tile_units[idx], tile_id, owner_id)
end

return EggyLayerBoard
