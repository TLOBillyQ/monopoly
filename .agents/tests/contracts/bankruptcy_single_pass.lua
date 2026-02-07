local bankruptcy_manager = require("src.game.game.BankruptcyManager")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local reset_ids = {}
local game = {
  board = {
    get_tile_by_id = function(_, id)
      local tiles = {
        [1] = { id = 1, name = "A" },
        [2] = { id = 2, name = "B" },
      }
      return tiles[id]
    end,
    index_of_tile_id = function(_, id)
      return id
    end,
  },
  store = {
    get = function(_, path)
      if path[1] == "players" and path[3] == "properties" then
        return { [1] = true }
      end
      return nil
    end,
    state = {
      board = {
        tiles = {
          [1] = { owner_id = 1 },
          [2] = { owner_id = 1 },
        },
      },
    },
  },
  occupants = {
    [1] = { 1 },
    [2] = { 1 },
  },
}

function game:reset_tile(tile)
  reset_ids[#reset_ids + 1] = tile.id
end

function game:set_player_property()
end

function game:sync_player_inventory()
end

function game:set_player_eliminated(player, eliminated)
  player.eliminated = eliminated == true
end

local player = {
  id = 1,
  name = "P1",
  eliminated = false,
  properties = { [1] = true, [2] = true },
  inventory = { items = {}, _suspend_on_change = false },
}

bankruptcy_manager.eliminate(game, player)

_assert_eq(#reset_ids, 1, "bankruptcy should reset one tile from Store properties")
_assert_eq(reset_ids[1], 1, "bankruptcy should only reset tile 1")

print("Contract bankruptcy_single_pass passed")
