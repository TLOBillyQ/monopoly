-- Mutation-pinning specs for src/turn/optional_action_choice.lua.
-- The predicate is pure, so choices are built inline (no runtime setup) and the
-- nil-vs-explicit-field discrimination is the contract under test.

local lu = require("luaunit")
local optional_action_choice = require("src.turn.optional_action_choice")

TestOptionalActionChoiceMutation = {}

local function _pre_action_choice(overrides)
  local choice = {
    kind = "item_phase_passive",
    allow_cancel = true,
    meta = { phase = "pre_action" },
  }
  for key, value in pairs(overrides or {}) do
    choice[key] = value
  end
  return choice
end

function TestOptionalActionChoiceMutation:test_excludes_a_pre_action_passive_whose_meta_passive_origin_is_true_l25_passive_origin_true()
  -- Item target selection (passive_origin) is a usage follow-up with its own
  -- base-cancel exit, so it must NOT be routed to the 行动 button. Mutant
  -- '~= true' -> '~= false' would accept passive_origin == true and wrongly
  -- report it as a pre_action choice.
  local choice = _pre_action_choice({ meta = { phase = "pre_action", passive_origin = true } })
  lu.assertEvalToTrue(optional_action_choice.is_pre_action_item_phase_passive(choice) == false,
    "passive_origin==true must be excluded from pre_action item-phase routing")
end

function TestOptionalActionChoiceMutation:test_includes_a_pre_action_passive_without_passive_origin_positive_control()
  lu.assertEvalToTrue(optional_action_choice.is_pre_action_item_phase_passive(_pre_action_choice()) == true,
    "a cancelable pre_action item_phase_passive without passive_origin must qualify")
end

-- 生产侧 followup choice 的真实形态（出生地：src/rules/items/handlers.lua 的
-- item_target_player/remote_dice_value/roadblock_target、demolish_choice.lua 的
-- demolish_target；装饰：item_phase_handlers._decorate_phase_followup 写
-- meta.passive_origin/item_id/player_id，item_phase.decorate_followup_choice_spec
-- 补 meta.phase 与 allow_cancel）。kind 因卡而异，谓词只认 passive_origin 标记。
local function _followup_choice(overrides)
  local choice = {
    id = 7,
    kind = "item_target_player",
    route_key = "player",
    allow_cancel = true,
    owner_role_id = 1,
    meta = { passive_origin = true, item_id = 2007, player_id = 1, phase = "pre_action" },
  }
  for key, value in pairs(overrides or {}) do
    choice[key] = value
  end
  return choice
end

-- 生产侧道具槽位窗（出生地：src/rules/items/phase.lua build_passive_choice_spec）：
-- kind=item_phase_passive、meta.phase 恒有值、恒无 passive_origin。它的退出口是
-- 行动/结束按钮（complete_optional_action_phase），不是基础屏取消按钮。
local function _slot_window_choice(phase)
  return {
    id = 3,
    kind = "item_phase_passive",
    allow_cancel = true,
    owner_role_id = 1,
    meta = { player_id = 1, phase = phase or "pre_action", resume_next_state = "roll" },
  }
end

function TestOptionalActionChoiceMutation:test_qualifies_a_production_followup_regardless_of_kind_positive_control()
  lu.assertEvalToTrue(optional_action_choice.is_item_target_selection_choice(_followup_choice()) == true,
    "meta.passive_origin==true marks an item usage follow-up whatever its kind")
  lu.assertEvalToTrue(optional_action_choice.is_item_target_selection_choice(_followup_choice({
    kind = "remote_dice_value", route_key = "remote",
    meta = { passive_origin = true, item_id = 2002, player_id = 1, phase = "pre_action" },
  })) == true, "the marker, not the kind, decides: remote dice followup qualifies too")
end

function TestOptionalActionChoiceMutation:test_rejects_the_slot_window_no_passive_origin()
  lu.assertEvalToTrue(optional_action_choice.is_item_target_selection_choice(_slot_window_choice()) == false,
    "the item phase slot window is not a usage follow-up")
end

function TestOptionalActionChoiceMutation:test_rejects_a_nil_choice_and_a_meta_less_choice()
  lu.assertEvalToTrue(optional_action_choice.is_item_target_selection_choice(nil) == false,
    "nil choice must not qualify")
  lu.assertEvalToTrue(optional_action_choice.is_item_target_selection_choice({ kind = "item_target_player" }) == false,
    "absent meta table must not qualify")
end

function TestOptionalActionChoiceMutation:test_requires_passive_origin_to_be_the_literal_true()
  lu.assertEvalToTrue(optional_action_choice.is_item_target_selection_choice(_followup_choice({
    meta = { passive_origin = 1, item_id = 2007, player_id = 1, phase = "pre_action" },
  })) == false, "only the literal true written by rules decoration qualifies")
end

function TestOptionalActionChoiceMutation:test_grants_base_cancel_for_a_cancelable_production_followup_positive_control()
  -- 基础屏取消按钮的唯一口径：渲染显隐(panel_action_controls)与意图构造(route_base)
  -- 都只问这个谓词。escrow/预消耗 followup 由 rules 侧写 allow_cancel=false 关掉。
  lu.assertEvalToTrue(optional_action_choice.is_base_cancel_choice(_followup_choice()) == true,
    "a cancelable followup owns the base cancel exit")
end

function TestOptionalActionChoiceMutation:test_treats_a_missing_allow_cancel_as_cancelable_false_contract()
  lu.assertEvalToTrue(optional_action_choice.is_base_cancel_choice(_followup_choice({ allow_cancel = nil })) == true,
    "allow_cancel defaults open; only an explicit false closes the exit")
end

function TestOptionalActionChoiceMutation:test_denies_base_cancel_when_rules_closed_the_exit_escrow_allow_cancel_false()
  -- escrow/预消耗由 rules 成对写 allow_cancel=false 与 meta.item_preconsumed。
  lu.assertEvalToTrue(optional_action_choice.is_base_cancel_choice(_followup_choice({
    allow_cancel = false,
    meta = { passive_origin = true, item_id = 2007, player_id = 1, phase = "pre_action", item_preconsumed = true },
  })) == false, "escrow/preconsumed followups must not offer the base cancel exit")
end

function TestOptionalActionChoiceMutation:test_denies_base_cancel_outside_a_followup()
  lu.assertEvalToTrue(optional_action_choice.is_base_cancel_choice(_slot_window_choice()) == false,
    "the slot window exits through 行动/结束, never the base cancel button")
  lu.assertEvalToTrue(optional_action_choice.is_base_cancel_choice(nil) == false,
    "no choice, no cancel intent")
end


return TestOptionalActionChoiceMutation
