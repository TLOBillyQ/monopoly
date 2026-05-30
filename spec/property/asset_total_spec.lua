local property = require("spec.support.property")
local asset_total = require("src.rules.land.asset_total")
local pricing = require("src.rules.land.pricing")

-- Build a random holding: a player with some cash and a set of owned land
-- tiles, each carrying a purchase price, a random upgrade-cost ladder, and a
-- level that may exceed the ladder length (so pricing's clamp is exercised).
-- The fake game exposes only what asset_total touches: the cash balance and a
-- board lookup keyed by tile id.
local function _gen_holding(rng)
  local cash = rng:int(0, 100000)
  local tile_count = rng:int(0, 8)
  local tiles, owned = {}, {}
  for id = 1, tile_count do
    local ladder = {}
    for _ = 1, rng:int(0, 4) do
      ladder[#ladder + 1] = rng:int(0, 1000)
    end
    tiles[id] = {
      id = id,
      type = "land",
      owner_id = 1,
      price = rng:int(0, 5000),
      upgrade_costs = ladder,
      level = rng:int(0, #ladder + 2),
    }
    owned[id] = true
  end
  return { cash = cash, tiles = tiles, owned = owned }
end

local function _game(cash, tiles)
  return {
    player_balance = function()
      return cash
    end,
    board = {
      get_tile_by_id = function(_, tile_id)
        return tiles[tile_id]
      end,
    },
  }
end

local function _player(owned)
  return { id = 1, properties = owned }
end

-- Independent oracle for one tile's invested value, using the same level
-- resolution (tile.level) that asset_total reads through tile.get_state.
local function _invested(tile)
  return pricing.total_invested(tile, tile.level)
end

describe("asset_total.player_total properties", function()
  it("conserves cash plus the invested value of every owned tile", function()
    property.for_all(_gen_holding, function(holding)
      local expected = holding.cash
      for id in pairs(holding.owned) do
        expected = expected + _invested(holding.tiles[id])
      end
      local total = asset_total.player_total(_game(holding.cash, holding.tiles), _player(holding.owned))
      assert(total == expected,
        "total must equal cash plus summed tile investment; got " .. tostring(total) .. " want " .. tostring(expected))
    end)
  end)

  it("adds exactly one tile's investment when that tile is added to the holding", function()
    property.for_all(_gen_holding, function(holding, rng)
      local ids = {}
      for id in pairs(holding.owned) do
        ids[#ids + 1] = id
      end
      if #ids == 0 then
        return
      end
      local dropped = ids[rng:int(1, #ids)]
      local without = {}
      for id in pairs(holding.owned) do
        if id ~= dropped then
          without[id] = true
        end
      end
      local game = _game(holding.cash, holding.tiles)
      local with_total = asset_total.player_total(game, _player(holding.owned))
      local without_total = asset_total.player_total(game, _player(without))
      assert(with_total - without_total == _invested(holding.tiles[dropped]),
        "adding a tile must raise the total by exactly that tile's invested value")
    end)
  end)

  it("shifts the total by exactly the change in cash", function()
    property.for_all(_gen_holding, function(holding, rng)
      local delta = rng:int(0, 50000)
      local base = asset_total.player_total(_game(holding.cash, holding.tiles), _player(holding.owned))
      local shifted = asset_total.player_total(_game(holding.cash + delta, holding.tiles), _player(holding.owned))
      assert(shifted - base == delta, "raising cash by d must raise the total by exactly d")
    end)
  end)
end)
