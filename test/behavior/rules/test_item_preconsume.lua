-- 原生 LuaUnit 迁移:三个 do 块 + describe 按钩子边界拍平为三个 Test* 类
-- (crap_coverage 与 guard paths 带 before_each → setUp;mutation pins 无钩子
-- → 无 setUp 类),重复的 local 辅助合并到文件级,断言词汇从 luassert
-- 兼容层切到 lu.assertXxx,用例数与改写前一一对应(5 + 1 + 10 = 16 例)。
local item_preconsume_policy = require("src.rules.choice.item_preconsume_policy")
local policy = require("src.rules.choice.item_preconsume_policy")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _assert_true(value, msg)
  assert(value == true, tostring(msg) .. ": expected true, got " .. tostring(value))
end

local function _assert_false(value, msg)
  assert(value == false, tostring(msg) .. ": expected false, got " .. tostring(value))
end

local function _assert_table(value, msg)
  assert(type(value) == "table", tostring(msg) .. ": expected table, got " .. type(value))
end

TestItemPreconsumeCrapCoverage = {}

function TestItemPreconsumeCrapCoverage:setUp()
  require("test.support.config_reset").reset_all()
end

function TestItemPreconsumeCrapCoverage:test_decorate_followup_choice_spec_empty_spec_gets_meta_added()
  local choice_spec = {}
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

  _assert_table(result, "result is table")
  _assert_table(result.meta, "meta added to spec")
  _assert_true(result.meta.item_preconsumed, "item_preconsumed set to true")
end

function TestItemPreconsumeCrapCoverage:test_decorate_followup_choice_spec_existing_meta_not_overwritten()
  local choice_spec = {
    meta = {
      item_preconsumed = false,
      custom_field = "custom_value"
    }
  }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

  _assert_table(result.meta, "meta preserved")
  _assert_true(result.meta.item_preconsumed, "item_preconsumed set to true")
  _assert_eq(result.meta.custom_field, "custom_value", "custom field preserved")
end

function TestItemPreconsumeCrapCoverage:test_decorate_followup_choice_spec_cancel_disabled_when_function_runs()
  local choice_spec = {
    allow_cancel = true,
    cancel_label = "Cancel Action"
  }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec)

  _assert_false(result.allow_cancel, "allow_cancel set to false")
  _assert_eq(result.cancel_label, nil, "cancel_label set to nil")
end

function TestItemPreconsumeCrapCoverage:test_decorate_followup_choice_spec_context_only_flag_handled()
  local choice_spec = {}
  local context = { context_only = true }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)

  _assert_table(result.meta, "meta created")
  _assert_true(result.meta.item_preconsumed, "item_preconsumed set despite extra context fields")
end

function TestItemPreconsumeCrapCoverage:test_decorate_followup_choice_spec_context_fields_merged_into_spec()
  local choice_spec = {}
  local context = {
    item_id = "item_123",
    player_id = "player_456"
  }
  local result = item_preconsume_policy.decorate_followup_choice_spec(choice_spec, context)

  _assert_table(result.meta, "meta created")
  _assert_eq(result.meta.item_id, "item_123", "item_id merged from context")
  _assert_eq(result.meta.player_id, "player_456", "player_id merged from context")
end

-- ===== merged from choice/test_item_preconsume_policy_mutation.lua =====
-- Mutation-pinning spec for src/rules/choice/item_preconsume_policy.lua.
-- Kills the normalize_cancel_action return-table survivors (L44/L45/L47):
--   * L44 type = "choice_select"           mutated to nil
--   * L45 choice_id = choice and choice.id or nil    `or` -> `and` (=> nil)
--   * L47 actor_role_id = action and action.actor_role_id or nil  `or` -> `and`
-- Reaching the return requires: cancel action + preconsumed choice + a first option.
TestItemPreconsumeNormalizeCancelAction = {}

function TestItemPreconsumeNormalizeCancelAction:test_rewrites_a_cancel_into_a_choice_select_carrying_every_field_l44_l45_l47()
  local choice = {
    id = "C1",
    meta = { item_preconsumed = true },
    options = { { id = "OPT_A" }, { id = "OPT_B" } },
  }
  local action = { type = "choice_cancel", actor_role_id = 7 }

  local result = policy.normalize_cancel_action(choice, action)

  _assert_eq(result.type, "choice_select", "rewritten action type must be 'choice_select' (L44)")
  _assert_eq(result.choice_id, "C1", "choice_id must be forwarded from choice.id (L45 'or')")
  _assert_eq(result.option_id, "OPT_A", "option_id must be the first option id (L46)")
  _assert_eq(result.actor_role_id, 7, "actor_role_id must be forwarded from the action (L47 'or')")
end

-- ===== non-table / empty-option guard paths =====
TestItemPreconsumeGuardPaths = {}

function TestItemPreconsumeGuardPaths:setUp()
  require("test.support.config_reset").reset_all()
end

function TestItemPreconsumeGuardPaths:test_keeps_the_cancel_action_when_a_preconsumed_choice_has_no_options_to_fall_back_to()
  local choice = { id = "C1", meta = { item_preconsumed = true }, options = {} }
  local action = { type = "choice_cancel", actor_role_id = 7 }

  local result = policy.normalize_cancel_action(choice, action)

  _assert_eq(result, action, "with no fallback option the cancel must pass through untouched")
end

function TestItemPreconsumeGuardPaths:test_keeps_a_non_cancel_action_untouched()
  local choice = { id = "C1", meta = { item_preconsumed = true }, options = { { id = "A" } } }
  local action = { type = "choice_select", option_id = "A" }

  _assert_eq(policy.normalize_cancel_action(choice, action), action, "non-cancel passes through")
end

function TestItemPreconsumeGuardPaths:test_keeps_a_cancel_action_untouched_when_the_choice_is_not_preconsumed()
  local choice = { id = "C1", options = { { id = "A" } } }
  local action = { type = "choice_cancel" }

  _assert_eq(policy.normalize_cancel_action(choice, action), action, "non-preconsumed passes through")
end

function TestItemPreconsumeGuardPaths:test_reads_the_first_option_id_from_a_bare_id_option_list()
  local choice = { options = { "RAW_A", "RAW_B" } }

  _assert_eq(policy.first_option_id(choice), "RAW_A", "bare string options expose themselves as the id")
end

function TestItemPreconsumeGuardPaths:test_returns_nil_for_a_first_option_id_when_options_are_not_a_table()
  _assert_eq(policy.first_option_id({ options = "nope" }), nil, "non-table options yield no id")
  _assert_eq(policy.first_option_id(nil), nil, "nil choice yields no id")
end

function TestItemPreconsumeGuardPaths:test_passes_a_non_table_choice_spec_straight_back_out_of_disable_followup_cancel()
  _assert_eq(policy.disable_followup_cancel("nope"), "nope", "non-table spec returned as-is")
end

function TestItemPreconsumeGuardPaths:test_returns_no_meta_for_a_non_table_choice_spec()
  _assert_eq(policy.ensure_followup_meta("nope"), nil, "non-table spec has no meta to ensure")
end

function TestItemPreconsumeGuardPaths:test_returns_a_non_table_meta_untouched_from_merge_preconsume_context()
  _assert_eq(policy.merge_preconsume_context("nope", { item_id = "I" }), "nope", "non-table meta as-is")
end

function TestItemPreconsumeGuardPaths:test_does_not_overwrite_meta_fields_that_are_already_set()
  local meta = { item_id = "KEEP", player_id = "KEEP_P" }

  policy.merge_preconsume_context(meta, { item_id = "NEW", player_id = "NEW_P" })

  _assert_eq(meta.item_id, "KEEP", "existing item_id wins over context")
  _assert_eq(meta.player_id, "KEEP_P", "existing player_id wins over context")
end

function TestItemPreconsumeGuardPaths:test_leaves_meta_fields_absent_when_the_context_carries_none()
  local meta = {}

  policy.merge_preconsume_context(meta, {})

  _assert_eq(meta.item_id, nil, "no item_id in context means none written")
  _assert_eq(meta.player_id, nil, "no player_id in context means none written")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestItemPreconsumeCrapCoverage,
  TestItemPreconsumeNormalizeCancelAction,
  TestItemPreconsumeGuardPaths
)
