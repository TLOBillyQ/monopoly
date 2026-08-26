-- ui/view/tile_rent 的 for_level 租金计算,按地皮价格与升级等级算租金。
--
-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):describe/it 拍平为文件级 Test*
-- 类,断言从 luassert 兼容层切到 lu.assertXxx,用例数与改写前一一对应(6 例)。
local lu = require("luaunit")
local tile_rent = require("src.ui.view.tile_rent")

TestTileRent = {}

function TestTileRent:test_calculates_base_rent_at_level_0_for_a_tile_with_price_but_no_upgrade_costs()
  local tile = { price = 200.0 }
  local rent = tile_rent.for_level(tile, 0)
  -- base rent: floor(200 * 1 * 0.5) = 100
  lu.assertEvalToTrue(rent == 100.0, "base rent should be half the price, got " .. tostring(rent))
end

-- 闭合变异: _max_level 无 upgrade_costs 时返回 0,突变 0→1 会让 clamp 上界变大,
-- 造成非升级地皮被按升级等级算租金。
TestTileRent["test_clamps to level 0 for a tile without upgrade_costs even when level > 0 is requested"] = function(self)
  local tile = { price = 200.0 }
  local rent = tile_rent.for_level(tile, 3)
  -- without upgrade_costs, max_level=0, clamp(3, 0, 0) = 0
  lu.assertEvalToTrue(rent == 100.0, "rent must be base level when no upgrades exist, got " .. tostring(rent))
end

function TestTileRent:test_returns_nil_for_a_nil_tile()
  lu.assertEvalToTrue(tile_rent.for_level(nil, 0) == nil, "nil tile must return nil")
end

function TestTileRent:test_returns_nil_when_tile_has_no_price()
  lu.assertEvalToTrue(tile_rent.for_level({}, 0) == nil, "no-price tile must return nil")
end

function TestTileRent:test_calculates_upgraded_rent_at_level_1()
  local tile = { price = 100.0, upgrade_costs = { 50.0, 100.0 } }
  local rent = tile_rent.for_level(tile, 1)
  -- level 1 rent: floor(100 * 2 * 0.5) = 100
  lu.assertEvalToTrue(rent == 100.0, "level 1 rent should be price, got " .. tostring(rent))
end

function TestTileRent:test_clamps_requested_level_to_max_available_upgrades()
  local tile = { price = 100.0, upgrade_costs = { 50.0 } }
  local rent = tile_rent.for_level(tile, 99)
  -- max_level = 1, clamp(99, 0, 1) = 1
  -- level 1 rent: floor(100 * 2 * 0.5) = 100
  lu.assertEvalToTrue(rent == 100.0, "level must be clamped to max upgrades, got " .. tostring(rent))
end


return TestTileRent
