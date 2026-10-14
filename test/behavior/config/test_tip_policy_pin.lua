require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- tip_policy 布尔旗标 pin:#293 复核——18 个 true↔false 位点存活,根因是
-- 没有任何测试断言过这些旗标。逐条硬编码钉死,一次击杀全部。

local tip_policy = require("src.config.tip_policy")
local kinds = require("src.config.gameplay.event_kinds")

local function _tip_flag(kind_name)
  return tip_policy[kind_name] and tip_policy[kind_name].tip or false
end

describe("TestTipPolicyPin", function()

  it("test_tip_flags_are_pinned_per_event_kind", function()
    luassert.truthy(_tip_flag(kinds.dice_roll) == false, "dice_roll should not tip")
    luassert.truthy(_tip_flag(kinds.rent_paid) == true, "rent_paid should tip")
    luassert.truthy(_tip_flag(kinds.tax_paid) == true, "tax_paid should tip")
    luassert.truthy(_tip_flag(kinds.medical_fee) == true, "medical_fee should tip")
    luassert.truthy(_tip_flag(kinds.hospital_stay) == true, "hospital_stay should tip")
    luassert.truthy(_tip_flag(kinds.mountain_stay) == true, "mountain_stay should tip")
    luassert.truthy(_tip_flag(kinds.land_purchase) == true, "land_purchase should tip")
    luassert.truthy(_tip_flag(kinds.land_upgrade) == true, "land_upgrade should tip")
    luassert.truthy(_tip_flag(kinds.transit) == false, "transit should not tip")
    luassert.truthy(_tip_flag(kinds.move_completed) == false, "move_completed should not tip")
    luassert.truthy(_tip_flag(kinds.roadblock_placed) == false, "roadblock_placed should not tip")
    luassert.truthy(_tip_flag(kinds.roadblock_triggered) == false, "roadblock_triggered should not tip")
    luassert.truthy(_tip_flag(kinds.mine_placed) == false, "mine_placed should not tip")
    luassert.truthy(_tip_flag(kinds.bankruptcy) == false, "bankruptcy should not tip")
    luassert.truthy(_tip_flag(kinds.victory) == false, "victory should not tip")
    luassert.truthy(_tip_flag(kinds.remote_dice) == true, "remote_dice should tip so the whole table sees who set which point (#103)")
    luassert.truthy(_tip_flag(kinds.dice_multiplier_breakdown) == false, "dice_multiplier_breakdown is a log-only line (#103)")
    luassert.truthy(_tip_flag(kinds.rent_multiplier_breakdown) == true, "rent_multiplier_breakdown should tip")
    luassert.truthy(_tip_flag(kinds.afk_auto_enabled) == true, "afk_auto_enabled should tip as a room-wide broadcast")
    luassert.truthy(_tip_flag(kinds.market_auto_skipped) == false, "market_auto_skipped should not tip")
  end)

  it("test_log_flags_are_pinned", function()
    luassert.truthy(tip_policy[kinds.choice_skipped].log == false, "choice_skipped should not log")
    luassert.truthy(tip_policy[kinds.turn_end].log == false, "turn_end should not log")
    luassert.truthy(tip_policy[kinds.market_auto_skipped].log ~= false, "market_auto_skipped must reach the action log so a delegated seat can see it was skipped")
  end)

end)
