local logger = require("src.core.Logger")
local inventory = require("src.game.item.ItemInventory")
local tile_renderer = require("src.ui.TileRenderer")

local bankruptcy_manager = {}


function bankruptcy_manager.eliminate(game, player)
  logger.event(player.name .. " 破产出局")

  local owned_tile_ids = {}
  local owned_tile_set = {}
  for tile_id in pairs(player.properties) do
    owned_tile_set[tile_id] = true
    table.insert(owned_tile_ids, tile_id)
  end
  local store_tiles = game.store and game.store.state and game.store.state.board and game.store.state.board.tiles
  if store_tiles then
    for tile_id, st in pairs(store_tiles) do
      if st and st.owner_id == player.id and not owned_tile_set[tile_id] then
        owned_tile_set[tile_id] = true
        table.insert(owned_tile_ids, tile_id)
      end
    end
  end
  local owned_tiles = {}
  if #owned_tile_ids > 0 then
    local names = {}
    for _, tile_id in ipairs(owned_tile_ids) do
      local tile = game.board:get_tile_by_id(tile_id)
      assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
      table.insert(owned_tiles, tile)
      table.insert(names, tile.name)
    end
    logger.event(player.name .. " 破产，清空地块: " .. table.concat(names, "、"))
  end
  for _, tile in ipairs(owned_tiles) do
    game:reset_tile(tile)
    game:set_player_property(player, tile.id, false)
  end

  inventory.clear(player)
  game:sync_player_inventory(player)

  game:set_player_eliminated(player, true)

  local ui_port = game.ui_port
  local scene = ui_port and ui_port.board_scene or nil
  if scene then
    local unit = scene.units_by_player_id and scene.units_by_player_id[player.id] or nil
    if not unit then
      unit = ui_port.player_units and ui_port.player_units[player.id] or nil
    end
    if unit and unit.die then
      unit.die()
    end

    if scene.building_unit_groups and scene.tiles then
      for _, tile_id in ipairs(owned_tile_ids) do
        local idx = game.board:index_of_tile_id(tile_id)
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
