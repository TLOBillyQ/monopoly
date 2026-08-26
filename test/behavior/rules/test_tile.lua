-- tile.lua 直测:cfg 缺省(price/upgrade_costs/rents)、初始等级、get_state 断言
-- 与 land 类型守卫。类名与断言消息类变异属等价(申报),这里钉行为面。
local lu = require("luaunit")
local luax = require("test.support.luax")

local tile = require("src.rules.board.tile")

TestTile = {}

local function _tile(cfg)
  local merged = { id = 1, name = "路", type = "land", row = 1, col = 1 }
  for k, v in pairs(cfg or {}) do
    merged[k] = v
  end
  return tile:new(merged)
end

function TestTile:test_missing_price_defaults_to_zero()
  lu.assertEvalToTrue(_tile().price == 0, "a cfg without price must default to 0")
end

function TestTile:test_missing_upgrade_costs_defaults_to_an_empty_table()
  local t = _tile()
  lu.assertEvalToTrue(type(t.upgrade_costs) == "table" and #t.upgrade_costs == 0,
    "a cfg without upgrade_costs must default to an empty table")
end

function TestTile:test_missing_rents_defaults_to_an_empty_table()
  local t = _tile()
  lu.assertEvalToTrue(type(t.rents) == "table" and #t.rents == 0,
    "a cfg without rents must default to an empty table")
end

function TestTile:test_level_starts_at_zero()
  lu.assertEvalToTrue(_tile().level == 0, "a fresh tile must be level 0")
end

function TestTile:test_get_state_reads_owner_and_level()
  local t = _tile()
  t.owner_id = 7
  t.level = 2
  local state = tile.get_state({}, t)
  lu.assertEvalToTrue(state.owner_id == 7, "owner_id must pass through")
  lu.assertEvalToTrue(state.level == 2, "level must pass through")
end

function TestTile:test_get_state_rejects_non_land_tiles()
  luax.has_error(function()
    tile.get_state({}, { type = "chance" })
  end, "Tile.GetState requires land tile")
end

function TestTile:test_get_state_rejects_a_nil_tile()
  luax.has_error(function()
    tile.get_state({}, nil)
  end, "Tile.GetState requires land tile")
end

return TestTile
