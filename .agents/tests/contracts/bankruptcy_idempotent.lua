local bankruptcy_manager = require("src.game.game.BankruptcyManager")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function _build_game()
  local tiles = {
    [1] = { id = 1, name = "A" },
    [2] = { id = 2, name = "B" },
  }
  local game = {
    board = {
      get_tile_by_id = function(_, id)
        return tiles[id]
      end,
      index_of_tile_id = function(_, id)
        return id
      end,
    },
    occupants = {
      [1] = { 1 },
      [2] = { 1 },
    },
    store = {
      get = function(_, path)
        if path[1] == "players" and path[3] == "properties" then
          return { [1] = true, [2] = true }
        end
        return nil
      end,
      state = {
        players = {},
      },
    },
  }

  local counters = {
    reset_tile = 0,
    set_player_property = 0,
    sync_player_inventory = 0,
    set_player_eliminated = 0,
  }

  function game:reset_tile()
    counters.reset_tile = counters.reset_tile + 1
  end

  function game:set_player_property()
    counters.set_player_property = counters.set_player_property + 1
  end

  function game:sync_player_inventory()
    counters.sync_player_inventory = counters.sync_player_inventory + 1
  end

  function game:set_player_eliminated(player, eliminated)
    player.eliminated = eliminated == true
    counters.set_player_eliminated = counters.set_player_eliminated + 1
  end

  return game, counters
end

local game, counters = _build_game()
local player = {
  id = 1,
  name = "P1",
  eliminated = false,
  properties = { [1] = true, [2] = true },
  inventory = { items = { { id = 1 } }, _suspend_on_change = false },
}

bankruptcy_manager.eliminate(game, player)
local first = {
  reset_tile = counters.reset_tile,
  set_player_property = counters.set_player_property,
  sync_player_inventory = counters.sync_player_inventory,
  set_player_eliminated = counters.set_player_eliminated,
}

bankruptcy_manager.eliminate(game, player)

_assert_eq(counters.reset_tile, first.reset_tile, "reset_tile idempotent")
_assert_eq(counters.set_player_property, first.set_player_property, "set_player_property idempotent")
_assert_eq(counters.sync_player_inventory, first.sync_player_inventory, "sync_player_inventory idempotent")
_assert_eq(counters.set_player_eliminated, first.set_player_eliminated, "set_player_eliminated idempotent")

print("Contract bankruptcy_idempotent passed")
