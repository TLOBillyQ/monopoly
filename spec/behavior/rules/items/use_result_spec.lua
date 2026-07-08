-- use_result 构造器与 canonicalize 的直接单测(深化迁移 step 1)。
-- 六种历史 raw 形状逐一钉死,不依赖活流量杀变异体。
local use_result = require("src.rules.items.use_result")

local function _assert_eq(actual, expected, msg)
  assert(actual == expected, tostring(msg) .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

describe("item use_result", function()
  it("builds applied results with closed field set", function()
    local anim = { marker = "anim" }
    local result = use_result.applied({ action_anim = anim, consumed_by_applier = true })

    _assert_eq(use_result.is_result(result), true, "applied should be a result value")
    _assert_eq(result.status, "applied", "applied status")
    _assert_eq(result.action_anim, anim, "applied should preserve anim value")
    _assert_eq(result.consumed_by_applier, true, "applied consumed marker")
    assert(not pcall(use_result.applied, { unknown_field = 1 }), "unknown applied field must error")
  end)

  it("requires a stable reason for rejected results", function()
    local result = use_result.rejected("bag_full", { consumed_by_applier = false })

    _assert_eq(result.status, "rejected", "rejected status")
    _assert_eq(result.reason, "bag_full", "rejected reason")
    assert(not pcall(use_result.rejected), "missing reason must error")
    assert(not pcall(use_result.rejected, ""), "empty reason must error")
  end)

  it("requires a choice_spec for await_choice results", function()
    local spec = { kind = "item_target_player", options = {} }
    local result = use_result.await_choice(spec)

    _assert_eq(result.status, "await_choice", "await status")
    _assert_eq(result.choice_spec, spec, "await choice spec")
    assert(not pcall(use_result.await_choice), "missing choice_spec must error")
  end)

  it("canonicalizes plain true as applied", function()
    local result = use_result.canonicalize(true)

    _assert_eq(result.status, "applied", "plain true should be applied")
    _assert_eq(result.raw, true, "plain true raw preserved")
  end)

  it("canonicalizes false and non-tables as rejected with fallback reason", function()
    local from_false = use_result.canonicalize(false, "no_candidates")
    local from_nil = use_result.canonicalize(nil)

    _assert_eq(from_false.status, "rejected", "false should reject")
    _assert_eq(from_false.reason, "no_candidates", "false should take fallback reason")
    _assert_eq(from_nil.status, "rejected", "nil should reject")
    _assert_eq(from_nil.reason, "effect_rejected", "nil should take default reason")
  end)

  it("canonicalizes waiting tables as await_choice regardless of ok flag", function()
    local spec = { kind = "remote_dice_value" }
    local result = use_result.canonicalize({ waiting = true, ok = false, intent = { choice_spec = spec } })

    _assert_eq(result.status, "await_choice", "waiting must classify as await, not success or failure")
    _assert_eq(result.choice_spec, spec, "waiting choice spec extracted")
  end)

  it("canonicalizes ok=false tables preserving reason and bag_full fallback", function()
    local with_reason = use_result.canonicalize({ ok = false, reason = "blocked", item_consumed = true })
    local bag_full = use_result.canonicalize({ ok = false, bag_full = true }, "fallback")
    local bare = use_result.canonicalize({ ok = false }, "invalid_target")

    _assert_eq(with_reason.status, "rejected", "ok=false should reject")
    _assert_eq(with_reason.reason, "blocked", "explicit reason wins")
    _assert_eq(with_reason.consumed_by_applier, true, "legacy item_consumed carries over")
    _assert_eq(bag_full.reason, "bag_full", "bag_full beats fallback")
    _assert_eq(bare.reason, "invalid_target", "bare failure takes fallback")
  end)

  it("canonicalizes success tables with and without ok flag", function()
    local anim = { marker = "anim" }
    local with_ok = use_result.canonicalize({ ok = true, action_anim = anim, item_consumed = true })
    local without_ok = use_result.canonicalize({ action_anim = true })

    _assert_eq(with_ok.status, "applied", "ok=true should apply")
    _assert_eq(with_ok.action_anim, anim, "anim value preserved")
    _assert_eq(with_ok.consumed_by_applier, true, "legacy item_consumed carries over")
    _assert_eq(without_ok.status, "applied", "table without ok should apply")
  end)

  it("passes through values that are already results", function()
    local original = use_result.applied({})

    _assert_eq(use_result.canonicalize(original), original, "canonicalize must be idempotent on results")
  end)
end)
