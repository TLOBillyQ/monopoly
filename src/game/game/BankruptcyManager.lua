local logger = require("src.core.Logger")
local inventory = require("src.game.item.ItemInventory")
local tile_renderer = require("src.ui.TileRenderer")

local bankruptcy_manager = {}

local function _collect_owned_tiles(game, player)
  local owned_tile_ids = {}
  local owned_tile_set = {}
  for tile_id in pairs(player.properties) do
    owned_tile_set[tile_id] = true
    table.insert(owned_tile_ids, tile_id)
  end

  local store = game.store
  local store_tiles = store and store.state and store.state.board and store.state.board.tiles or nil
  if store_tiles then
    for tile_id, st in pairs(store_tiles) do
      if st and st.owner_id == player.id and not owned_tile_set[tile_id] then
        owned_tile_set[tile_id] = true
        table.insert(owned_tile_ids, tile_id)
      end
    end
  end

  local owned_tiles = {}
  local names = {}
  for _, tile_id in ipairs(owned_tile_ids) do
    local tile = game.board:get_tile_by_id(tile_id)
    assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
    table.insert(owned_tiles, tile)
    table.insert(names, tile.name)
  end

  return owned_tile_ids, owned_tiles, names
end

local function _clear_scene_tiles(scene, board, owned_tile_ids)
  if not scene or not scene.building_unit_groups or not scene.tiles then
    return
  end
  for _, tile_id in ipairs(owned_tile_ids) do
    local idx = board:index_of_tile_id(tile_id)
    local building = scene.building_unit_groups[idx]
    if building then
      GameAPI.destroy_unit_with_children(building, true)
      scene.building_unit_groups[idx] = nil
    end
    local tile_unit = scene.tiles[idx]
    if tile_unit then
      tile_renderer.render_tile(tile_unit, tile_id, nil)
    end
  end
end

function bankruptcy_manager.eliminate(game, player)
  if player.eliminated then
    return
  end
  logger.event(player.name .. " 破产出局")

  local owned_tile_ids, owned_tiles, names = _collect_owned_tiles(game, player)
  if #owned_tile_ids > 0 then
    logger.event(player.name .. " 破产，清空地块: " .. table.concat(names, "、"))

    for _, tile in ipairs(owned_tiles) do
      game:reset_tile(tile)
      game:set_player_property(player, tile.id, false)
    end
  end

  inventory.clear(player)
  game:sync_player_inventory(player)

  game:set_player_eliminated(player, true)

  local ui_port = game.ui_port
  local scene = ui_port and ui_port.board_scene or nil
  if GameAPI and GameAPI.get_role then
    local role = GameAPI.get_role(player.id)
    if role and role.lose then
      role.lose()
    end
  end

  if #owned_tile_ids > 0 then
    _clear_scene_tiles(scene, game.board, owned_tile_ids)
  end

  for tile_idx, list in pairs(game.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
end

return bankruptcy_manager
