local cash_display = require("src.rules.market.cash_display")

local function _make_game(cash_map)
  return {
    player_cash = function(_, player)
      return cash_map[player] or 0
    end,
  }
end

describe("market cash_display", function()
  it("returns player cash balance", function()
    local p = {}
    local game = _make_game({ [p] = 1000 })
    assert(cash_display.for_player(game, p) == 1000, "should return 1000")
  end)

  it("returns 0 when player has no cash", function()
    local p = {}
    local game = _make_game({ [p] = 0 })
    assert(cash_display.for_player(game, p) == 0, "should return 0")
  end)

  it("returns 0 when balance is nil", function()
    local p = {}
    local game = {
      player_cash = function() return nil end,
    }
    assert(cash_display.for_player(game, p) == 0, "nil balance should default to 0")
  end)

  it("returns different amounts for different players", function()
    local p1, p2 = {}, {}
    local game = _make_game({ [p1] = 500, [p2] = 3000 })
    assert(cash_display.for_player(game, p1) == 500, "p1 should have 500")
    assert(cash_display.for_player(game, p2) == 3000, "p2 should have 3000")
  end)
end)
