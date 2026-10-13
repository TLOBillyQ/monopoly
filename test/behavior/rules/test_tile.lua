require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- tile.lua 直测:cfg 缺省(price/upgrade_costs/rents)、初始等级、get_state 断言
-- 与 land 类型守卫。类名与断言消息类变异属等价(申报),这里钉行为面。

local tile = require("src.rules.board.tile")


local function _tile(cfg)
  local merged = { id = 1, name = "路", type = "land", row = 1, col = 1 }
  for k, v in pairs(cfg or {}) do
    merged[k] = v
  end
  return tile:new(merged)
end

describe("TestTile", function()
  it("test_missing_price_defaults_to_zero", function()
    luassert.truthy(_tile().price == 0, "a cfg without price must default to 0")
  end)

  it("test_missing_upgrade_costs_defaults_to_an_empty_table", function()
    local t = _tile()
    luassert.truthy(type(t.upgrade_costs) == "table" and #t.upgrade_costs == 0, "a cfg without upgrade_costs must default to an empty table")
  end)

  it("test_missing_rents_defaults_to_an_empty_table", function()
    local t = _tile()
    luassert.truthy(type(t.rents) == "table" and #t.rents == 0, "a cfg without rents must default to an empty table")
  end)

  it("test_level_starts_at_zero", function()
    luassert.truthy(_tile().level == 0, "a fresh tile must be level 0")
  end)

  it("test_get_state_reads_owner_and_level", function()
    local t = _tile()
    t.owner_id = 7
    t.level = 2
    local state = tile.get_state({}, t)
    luassert.truthy(state.owner_id == 7, "owner_id must pass through")
    luassert.truthy(state.level == 2, "level must pass through")
  end)

  it("test_get_state_rejects_non_land_tiles", function()
    luassert.has_error(function()
      tile.get_state({}, { type = "chance" })
    end, "Tile.GetState requires land tile")
  end)

  it("test_get_state_rejects_a_nil_tile", function()
    luassert.has_error(function()
      tile.get_state({}, nil)
    end, "Tile.GetState requires land tile")
  end)

end)
