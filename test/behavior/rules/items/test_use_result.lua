-- use_result 构造器与 canonicalize 的直接单测(深化迁移 step 1)。
-- 六种历史 raw 形状逐一钉死,不依赖活流量杀变异体。
local lu = require("luaunit")
local luax = require("test.support.luax")
local use_result = require("src.rules.items.use_result")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

TestUseResult = {}

function TestUseResult:test_builds_applied_results_with_closed_field_set()
  local anim = { marker = "anim" }
  local result = use_result.applied({ action_anim = anim, consumed_by_applier = true })

  _assert_eq(use_result.is_result(result), true, "applied should be a result value")
  _assert_eq(result.status, "applied", "applied status")
  _assert_eq(result.action_anim, anim, "applied should preserve anim value")
  _assert_eq(result.consumed_by_applier, true, "applied consumed marker")
  lu.assertEvalToTrue(not pcall(use_result.applied, { unknown_field = 1 }), "unknown applied field must error")
end

function TestUseResult:test_requires_a_stable_reason_for_rejected_results()
  local result = use_result.rejected("handler_blocked", { consumed_by_applier = false })

  _assert_eq(result.status, "rejected", "rejected status")
  _assert_eq(result.reason, "handler_blocked", "rejected reason")
  -- pcall 只钉失败不钉消息;改 has_error 精确匹配封死 message -> nil。
  luax.has_error(function()
    use_result.rejected()
  end, "rejected requires a stable reason")
  luax.has_error(function()
    use_result.rejected("")
  end, "rejected requires a stable reason")
end

function TestUseResult:test_requires_a_choice_spec_for_await_choice_results()
  local spec = { kind = "item_target_player", options = {} }
  local result = use_result.await_choice(spec)

  _assert_eq(result.status, "await_choice", "await status")
  _assert_eq(result.choice_spec, spec, "await choice spec")
  luax.has_error(function()
    use_result.await_choice()
  end, "await_choice requires a choice_spec table")
end

function TestUseResult:test_canonicalizes_plain_true_as_applied()
  local result = use_result.canonicalize(true)

  _assert_eq(result.status, "applied", "plain true should be applied")
  _assert_eq(result.raw, true, "plain true raw preserved")
end

function TestUseResult:test_canonicalizes_false_and_non_tables_as_rejected_with_fallback_reason()
  local from_false = use_result.canonicalize(false, "no_candidates")
  local from_nil = use_result.canonicalize(nil)

  _assert_eq(from_false.status, "rejected", "false should reject")
  _assert_eq(from_false.reason, "no_candidates", "false should take fallback reason")
  _assert_eq(from_nil.status, "rejected", "nil should reject")
  _assert_eq(from_nil.reason, "effect_rejected", "nil should take default reason")
end

function TestUseResult:test_canonicalizes_waiting_tables_as_await_choice_regardless_of_ok_flag()
  local spec = { kind = "remote_dice_value" }
  local result = use_result.canonicalize({ waiting = true, ok = false, intent = { choice_spec = spec } })

  _assert_eq(result.status, "await_choice", "waiting must classify as await, not success or failure")
  _assert_eq(result.choice_spec, spec, "waiting choice spec extracted")
end

function TestUseResult:test_canonicalizes_ok_false_tables_preserving_reason_with_fallback()
  local with_reason = use_result.canonicalize({ ok = false, reason = "blocked", item_consumed = true })
  local bare = use_result.canonicalize({ ok = false }, "invalid_target")

  _assert_eq(with_reason.status, "rejected", "ok=false should reject")
  _assert_eq(with_reason.reason, "blocked", "explicit reason wins")
  _assert_eq(with_reason.consumed_by_applier, true, "legacy item_consumed carries over")
  _assert_eq(bare.reason, "invalid_target", "bare failure takes fallback")
end

function TestUseResult:test_canonicalizes_success_tables_with_and_without_ok_flag()
  local anim = { marker = "anim" }
  local with_ok = use_result.canonicalize({ ok = true, action_anim = anim, item_consumed = true })
  local without_ok = use_result.canonicalize({ action_anim = true })

  _assert_eq(with_ok.status, "applied", "ok=true should apply")
  _assert_eq(with_ok.action_anim, anim, "anim value preserved")
  _assert_eq(with_ok.consumed_by_applier, true, "legacy item_consumed carries over")
  _assert_eq(without_ok.status, "applied", "table without ok should apply")
end

function TestUseResult:test_passes_through_values_that_are_already_results()
  local original = use_result.applied({})

  _assert_eq(use_result.canonicalize(original), original, "canonicalize must be idempotent on results")
end


return TestUseResult
