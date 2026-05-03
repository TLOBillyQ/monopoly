local bankruptcy = require("src.rules.endgame.bankruptcy")

local function _make_player(name, deity)
  return {
    id = 1,
    name = name,
    status = { deity = deity },
    inventory = { items = {}, _suspend_on_change = false },
    eliminated = false,
    properties = {},
  }
end

local function _make_game()
  return {
    board = { path = {}, get_tile_by_id = function() return nil end },
    occupants = {},
    clear_player_deity = function(self, player)
      player.status.deity = { type = "", remaining = 0 }
    end,
    set_player_eliminated = function(self, player, eliminated)
      player.eliminated = eliminated
    end,
    reset_tile = function() end,
    set_player_property = function() end,
  }
end

describe("bankruptcy clears deity", function()
  local cases = {
    { name = "rich", deity = { type = "rich", remaining = 4 } },
    { name = "poor", deity = { type = "poor", remaining = 5 } },
    { name = "angel", deity = { type = "angel", remaining = 2 } },
    { name = "no-deity", deity = nil },
  }

  for _, case in ipairs(cases) do
    it("clears deity for " .. case.name .. " player", function()
      local game = _make_game()
      local player = _make_player(case.name, case.deity)

      bankruptcy.eliminate(game, player)

      assert(player.status.deity.type == "", "deity type should be cleared")
      assert(player.status.deity.remaining == 0, "deity remaining should be zero")
      assert(player.eliminated == true, "player should be eliminated")
    end)
  end
end)
