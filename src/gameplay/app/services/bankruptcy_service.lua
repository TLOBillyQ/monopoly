local logger = require("src.util.logger")

local BankruptcyService = {}


function BankruptcyService.eliminate(game, player)
  logger.event(player.name .. " 破产出局")
  
  local owned_tile_ids = {}
  for tile_id in pairs(player.properties) do
    table.insert(owned_tile_ids, tile_id)
  end
  for _, tile_id in ipairs(owned_tile_ids) do
    local tile = game.board:get_tile_by_id(tile_id)
    if tile then
      game:reset_tile(tile)
    end
    if game and game.set_player_property then
      game:set_player_property(player, tile_id, false)
    end
  end

  if player.inventory then
    player.inventory._suspend_on_change = true
    player.inventory.items = {}
    player.inventory._suspend_on_change = false
  end
  if game and game.sync_player_inventory then
    game:sync_player_inventory(player)
  end

  if game and game.set_player_eliminated then
    game:set_player_eliminated(player, true)
  else
    player.eliminated = true
  end
  
  for tile_idx, list in pairs(game.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
end

return BankruptcyService
