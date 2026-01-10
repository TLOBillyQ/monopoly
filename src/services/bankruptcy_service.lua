local logger = require("src.services.logger")

local BankruptcyService = {}

function BankruptcyService.eliminate(game, player)
  logger.event(player.name .. " 破产出局")
  -- 释放地皮
  for tile_id in pairs(player.properties) do
    local tile = game.board:get_tile_by_id(tile_id)
    if tile then
      tile:reset()
    end
  end
  player.properties = {}
  player.inventory.items = {}
  player.eliminated = true
  -- 移出占位
  for tile_idx, list in pairs(game.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
end

return BankruptcyService
