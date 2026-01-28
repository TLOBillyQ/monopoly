local BuildingEffects = require("src.adapters.eggy.building_effects")
local TileRenderer = require("src.adapters.eggy.tile_renderer")

local EggyLayerBoard = {}

function EggyLayerBoard.refresh_board(layer, view, log_once, build_log_prefix)
  local players = view and view.state and view.state.players or nil
  if not players then
    return
  end

  local tile_count = view.board_tile_count or (view.board and #view.board.tiles) or 0
  if tile_count <= 0 then
    return
  end

  if not layer.tile_positions or #layer.tile_positions < tile_count then
    local tiles = nil
    if G and type(G.tiles) == "table" and #G.tiles >= tile_count then
      tiles = G.tiles
    else
      local tile_names = {}
      for i = 1, tile_count do
        tile_names[i] = "t" .. tostring(i)
      end
      tiles = LuaAPI.query_units(tile_names)
    end

    local positions = {}
    local missing = 0
    for i = 1, tile_count do
      local unit = tiles and tiles[i] or nil
      if unit and unit.get_position then
        positions[i] = unit.get_position()
      else
        missing = missing + 1
      end
    end

    layer.tile_units = tiles
    layer.tile_positions = positions

    local spacing = 0
    local spacing_count = 0
    for i = 1, tile_count - 1 do
      local a = positions[i]
      local b = positions[i + 1]
      if a and b and a.x and b.x then
        local dx = b.x - a.x
        local dy = (b.y or 0) - (a.y or 0)
        local dz = (b.z or 0) - (a.z or 0)
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist > 0 then
          spacing = spacing + dist
          spacing_count = spacing_count + 1
        end
      end
    end
    if spacing_count > 0 then
      layer.tile_spacing = (spacing / spacing_count) * 0.28
    end

    log_once(layer, "info", "tiles_ready", build_log_prefix(), "tile anchors ready:", tostring(tile_count))
    if missing > 0 then
      log_once(
        layer,
        "warn",
        "tiles_missing",
        build_log_prefix(),
        "tile anchors missing:",
        tostring(missing)
      )
    end
  end

  if not layer.player_units or layer.player_units_missing then
    local roles = GameAPI.get_all_valid_roles() or {}
    local name_to_unit = {}
    local role_units = {}
    for i, role in ipairs(roles) do
      local unit = role and role.get_ctrl_unit and role.get_ctrl_unit() or nil
      role_units[i] = unit
      if role and role.get_name then
        local name = role.get_name()
        if name then
          name_to_unit[name] = unit
        end
      end
    end

    local mapped = {}
    local mapped_count = 0
    local missing = {}
    for i, player in ipairs(players) do
      if player then
        local pid = player.id or i
        local unit = nil
        if player.name then
          unit = name_to_unit[player.name]
        end
        if not unit then
          unit = role_units[pid] or role_units[i]
        end
        if unit then
          mapped[pid] = unit
          mapped_count = mapped_count + 1
        else
          missing[#missing + 1] = player.name or tostring(pid)
        end
      end
    end

    layer.player_units = mapped
    layer.player_units_missing = #missing > 0
    log_once(
      layer,
      "info",
      "player_units_ready",
      build_log_prefix(),
      "player->unit mapped:",
      tostring(mapped_count),
      "(missing:",
      tostring(#missing) .. ")"
    )
    if #missing > 0 then
      log_once(
        layer,
        "warn",
        "player_units_missing",
        build_log_prefix(),
        "player unit missing:",
        table.concat(missing, ", ")
      )
    end
  end

  local store = layer.game and layer.game.store
  local phase = store and store.get and store:get({ "turn", "phase" }) or nil
  local anim = store and store.get and store:get({ "turn", "move_anim" }) or nil
  local suppress_sync = phase == "wait_move_anim" and anim ~= nil

  local snapshot = {}
  for i, player in ipairs(players) do
    if player then
      local pid = player.id or i
      local pos = player.position
      local eliminated = player.eliminated and 1 or 0
      snapshot[pid] = tostring(pos) .. ":" .. tostring(eliminated)
    end
  end

  local need_sync = layer.board_sync_pending or false
  local last_positions = layer.board_last_positions
  if not need_sync then
    if not last_positions then
      need_sync = true
    else
      for pid, value in pairs(snapshot) do
        if last_positions[pid] ~= value then
          need_sync = true
          break
        end
      end
      if not need_sync then
        for pid, _ in pairs(last_positions) do
          if snapshot[pid] == nil then
            need_sync = true
            break
          end
        end
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
    if player and not player.eliminated and player.position then
      local idx = player.position
      if layer.tile_positions and layer.tile_positions[idx] then
        local pid = player.id or i
        local list = occupants[idx]
        if not list then
          list = {}
          occupants[idx] = list
        end
        list[#list + 1] = pid
      end
    end
  end

  local spacing = layer.tile_spacing or 0
  for i, player in ipairs(players) do
    if player and not player.eliminated and player.position then
      local idx = player.position
      local base = layer.tile_positions and layer.tile_positions[idx] or nil
      local pid = player.id or i
      local unit = layer.player_units and layer.player_units[pid] or nil
      if base and unit and unit.set_position then
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
          local per_row = math.ceil(math.sqrt(count))
          local row = math.floor((slot - 1) / per_row)
          local col = (slot - 1) % per_row
          local start = -(per_row - 1) * spacing * 0.5
          local ox = start + col * spacing
          local oz = start + row * spacing
          unit.set_position(base + math.Vector3(ox, 0, oz))
        else
          unit.set_position(base)
        end
      end
    end
  end

  layer.board_sync_pending = false
  layer.board_last_positions = snapshot
end

function EggyLayerBoard.on_tile_upgraded(layer, tile_id, level)
  if not (tile_id and level) then
    return
  end
  local buildings = G and G.buildings
  local refs = G and G.refs
  if not (buildings and refs) then
    return
  end
  local board = layer.game and layer.game.board
  if not (board and board.index_of_tile_id) then
    return
  end
  local idx = board:index_of_tile_id(tile_id)
  if not (idx and buildings[idx]) then
    return
  end
  local lv = tonumber(level)
  if not (lv and lv >= 1 and lv <= 3) then
    return
  end
  local root_quaternion = Q_ZERO
  if not root_quaternion and math and math.Quaternion then
    root_quaternion = math.Quaternion(0, 0, 0)
  end
  if not root_quaternion then
    return
  end
  BuildingEffects.spawn_upgrade_building_units(root_quaternion, idx, lv)
end

function EggyLayerBoard.on_tile_owner_changed(layer, tile_id, owner_id)
  if not tile_id then
    return
  end
  local board = layer.game and layer.game.board
  if not (board and board.index_of_tile_id) then
    return
  end
  local idx = board:index_of_tile_id(tile_id)
  if not (idx and layer.tile_units and layer.tile_units[idx]) then
    return
  end
  TileRenderer.render_tile(layer.tile_units[idx], tile_id, owner_id)
end

return EggyLayerBoard
