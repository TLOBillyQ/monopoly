local Logger = require("src.core.Logger")
local Inventory = require("src.game.item.ItemInventory")

local BankruptcyManager = {}


function BankruptcyManager.Eliminate(game, player)
  Logger.Event(player.name .. " 破产出局")

  local owned_tile_ids = {}
  local owned_tile_set = {}
  for tile_id in pairs(player.properties) do
    owned_tile_set[tile_id] = true
    table.insert(owned_tile_ids, tile_id)
  end
  local store_tiles = game.store:Get({ "board", "tiles" })
  for tile_id, st in pairs(store_tiles) do
    if st and st.owner_id == player.id and not owned_tile_set[tile_id] then
      owned_tile_set[tile_id] = true
      table.insert(owned_tile_ids, tile_id)
    end
  end
  if #owned_tile_ids > 0 then
    local names = {}
    for _, tile_id in ipairs(owned_tile_ids) do
      local tile = game.board:GetTileById(tile_id)
      table.insert(names, tile.name)
    end
    Logger.Event(player.name .. " 破产，清空地块: " .. table.concat(names, "、"))
  end
  for _, tile_id in ipairs(owned_tile_ids) do
    local tile = game.board:GetTileById(tile_id)
    game:ResetTile(tile)
    game:SetPlayerProperty(player, tile_id, false)
  end

  Inventory.Clear(player)
  game:SyncPlayerInventory(player)

  game:SetPlayerEliminated(player, true)

  for tile_idx, list in pairs(game.occupants) do
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
end

return BankruptcyManager


