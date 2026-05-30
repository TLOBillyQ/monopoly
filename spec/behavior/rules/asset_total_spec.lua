local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local asset_total = require("src.rules.land.asset_total")

local function _game(cash, tiles)
  return {
    player_balance = function(_, _, currency)
      _assert_eq(currency, "金币", "asset total should read cash balance")
      return cash
    end,
    board = {
      get_tile_by_id = function(_, tile_id)
        return tiles and tiles[tile_id] or nil
      end,
    },
  }
end

describe("asset_total", function()
  it("returns_cash_when_player_owns_no_tiles", function()
    local game = _game(50000, nil)
    local player = { id = 1, properties = {} }
    _assert_eq(asset_total.player_total(game, player), 50000, "asset total should equal cash without tiles")
  end)

  it("adds_total_invested_for_owned_land_tiles", function()
    local tile = {
      id = 7,
      type = "land",
      level = 2,
      price = 1000,
      upgrade_costs = { 500, 800, 1200 },
    }
    local game = _game(2000, { [7] = tile })
    local player = { id = 1, properties = { [7] = true } }

    -- cash 2000 + purchase 1000 + upgrades for level 2 (500 + 800) = 4300
    _assert_eq(asset_total.player_total(game, player), 4300, "asset total should add purchase and per-level upgrades")
  end)

  it("tolerates_player_without_properties_table", function()
    local game = _game(300, nil)
    local player = { id = 1 }
    _assert_eq(asset_total.player_total(game, player), 300, "asset total should treat missing properties as none")
  end)

  it("asserts_when_cash_balance_is_missing", function()
    local game = _game(nil, nil)
    local player = { id = 1, properties = {} }
    local ok = pcall(asset_total.player_total, game, player)
    _assert_eq(ok, false, "asset total should reject a nil cash balance")
  end)
end)
