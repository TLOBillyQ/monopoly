-- 原生 LuaUnit(自研 busted → LuaUnit 迁移):describe 与迁自 property 车道的
-- 内层 describe 均无钩子,不拆类直接合并进 TestAssetTotal,辅助函数提升到
-- 文件级,裸 assert(语句位)切 lu.assertEvalToTrue,用例数与改写前一一对应
-- (4 + 3 = 7 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local asset_total = require("src.rules.land.asset_total")

local function _game(cash, tiles)
  return {
    player_cash = function()
      return cash
    end,
    board = {
      get_tile_by_id = function(_, tile_id)
        return tiles and tiles[tile_id] or nil
      end,
    },
  }
end

-- ===== 迁自 test/property/test_asset_total.lua（#190, 测试极简化决策：property 车道退场，性质并入 behavior）=====
local property = require("test.support.property")
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

local function _prop_game(cash, tiles)
  return {
    player_cash = function()
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

TestAssetTotal = {}

function TestAssetTotal:test_returns_cash_when_player_owns_no_tiles()
  local game = _game(50000, nil)
  local player = { id = 1, properties = {} }
  _assert_eq(asset_total.player_total(game, player), 50000, "asset total should equal cash without tiles")
end

function TestAssetTotal:test_adds_total_invested_for_owned_land_tiles()
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
end

function TestAssetTotal:test_tolerates_player_without_properties_table()
  local game = _game(300, nil)
  local player = { id = 1 }
  _assert_eq(asset_total.player_total(game, player), 300, "asset total should treat missing properties as none")
end

function TestAssetTotal:test_asserts_when_cash_balance_is_missing()
  local game = _game(nil, nil)
  local player = { id = 1, properties = {} }
  local ok = pcall(asset_total.player_total, game, player)
  _assert_eq(ok, false, "asset total should reject a nil cash balance")
end

function TestAssetTotal:test_conserves_cash_plus_invested_value_of_every_owned_tile()
  property.for_all(_gen_holding, function(holding)
    local expected = holding.cash
    for id in pairs(holding.owned) do
      expected = expected + _invested(holding.tiles[id])
    end
    local total = asset_total.player_total(_prop_game(holding.cash, holding.tiles), _player(holding.owned))
    lu.assertEvalToTrue(total == expected,
      "total must equal cash plus summed tile investment; got " .. tostring(total) .. " want " .. tostring(expected))
  end)
end

function TestAssetTotal:test_adds_exactly_one_tiles_investment_when_tile_added()
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
    local game = _prop_game(holding.cash, holding.tiles)
    local with_total = asset_total.player_total(game, _player(holding.owned))
    local without_total = asset_total.player_total(game, _player(without))
    lu.assertEvalToTrue(with_total - without_total == _invested(holding.tiles[dropped]),
      "adding a tile must raise the total by exactly that tile's invested value")
  end)
end

function TestAssetTotal:test_shifts_total_by_exactly_the_change_in_cash()
  property.for_all(_gen_holding, function(holding, rng)
    local delta = rng:int(0, 50000)
    local base = asset_total.player_total(_prop_game(holding.cash, holding.tiles), _player(holding.owned))
    local shifted = asset_total.player_total(_prop_game(holding.cash + delta, holding.tiles), _player(holding.owned))
    lu.assertEvalToTrue(shifted - base == delta, "raising cash by d must raise the total by exactly d")
  end)
end



function TestAssetTotal:test_asserts_missing_player_cash_with_message()
  -- #293:player_total 的 missing player cash 断言消息未测。
  local game = {
    player_cash = function() return nil end,
    board = { get_tile_by_id = function() return nil end },
  }
  local ok, err = pcall(asset_total.player_total, game, { properties = {} })
  lu.assertEvalToTrue(ok == false, "nil player cash should assert")
  lu.assertEvalToTrue(tostring(err):find("missing player cash", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err))
end

function TestAssetTotal:test_asserts_invalid_property_tile_with_message()
  -- #293:无效地产断言消息未测。
  local game = {
    player_cash = function() return 100 end,
    board = { get_tile_by_id = function() return nil end },
  }
  local ok, err = pcall(asset_total.player_total, game, { properties = { t1 = true } })
  lu.assertEvalToTrue(ok == false, "invalid property tile should assert")
  lu.assertEvalToTrue(tostring(err):find("invalid property tile", 1, true) ~= nil,
    "assert should carry its message: " .. tostring(err))
end

return TestAssetTotal
