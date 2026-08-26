-- tip_policy 布尔旗标 pin:#293 复核——18 个 true↔false 位点存活,根因是
-- 没有任何测试断言过这些旗标。逐条硬编码钉死,一次击杀全部。
local lu = require("luaunit")

local tip_policy = require("src.config.tip_policy")
local kinds = require("src.config.gameplay.event_kinds")

local function _tip_flag(kind_name)
  return tip_policy[kind_name] and tip_policy[kind_name].tip or false
end

TestTipPolicyPin = {}

function TestTipPolicyPin:test_tip_flags_are_pinned_per_event_kind()
  lu.assertEvalToTrue(_tip_flag(kinds.dice_roll) == false, "dice_roll should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.rent_paid) == true, "rent_paid should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.tax_paid) == true, "tax_paid should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.medical_fee) == true, "medical_fee should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.hospital_stay) == true, "hospital_stay should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.mountain_stay) == true, "mountain_stay should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.land_purchase) == true, "land_purchase should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.land_upgrade) == true, "land_upgrade should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.transit) == false, "transit should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.move_completed) == false, "move_completed should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.roadblock_placed) == false, "roadblock_placed should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.roadblock_triggered) == false, "roadblock_triggered should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.mine_placed) == false, "mine_placed should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.bankruptcy) == false, "bankruptcy should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.victory) == false, "victory should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.remote_dice) == false, "remote_dice should not tip")
  lu.assertEvalToTrue(_tip_flag(kinds.rent_multiplier_breakdown) == true,
    "rent_multiplier_breakdown should tip")
  lu.assertEvalToTrue(_tip_flag(kinds.afk_auto_enabled) == true,
    "afk_auto_enabled should tip as a room-wide broadcast")
end

function TestTipPolicyPin:test_log_flags_are_pinned()
  lu.assertEvalToTrue(tip_policy[kinds.choice_skipped].log == false,
    "choice_skipped should not log")
  lu.assertEvalToTrue(tip_policy[kinds.turn_end].log == false,
    "turn_end should not log")
end

return TestTipPolicyPin
