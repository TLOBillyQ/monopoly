-- Branch-level coverage for src.config.choice.route_policy private helpers
-- (_non_empty_route_key, _boolean_field, _resolve_explicit_route,
--  _resolve_explicit_requires_confirm) via the public policy.resolve /
-- policy.requires_confirm surface.
-- Survivors from #293 batch 2.

local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local policy = require("src.config.choice.route_policy")

TestRoutePolicy = {}

-- ── policy.resolve: explicit route chain ──────────────────────────

function TestRoutePolicy:test_resolve_returns_route_key_from_choice_meta()
  local choice = {
    kind = "market_buy",
    meta = { route_key = "market" },
  }
  _assert_eq(policy.resolve(choice), "market", "resolve should fall through to meta.route_key")
end

function TestRoutePolicy:test_resolve_returns_route_key_from_choice_route_field()
  local choice = {
    kind = "remote_dice_value",
    route = { route_key = "remote" },
  }
  _assert_eq(policy.resolve(choice), "remote", "resolve should prefer choice.route.route_key over meta")
end

function TestRoutePolicy:test_resolve_returns_base_inline_when_choice_is_nil()
  _assert_eq(policy.resolve(nil), "base_inline", "nil choice should fall back to base_inline")
end

function TestRoutePolicy:test_resolve_returns_base_inline_when_no_explicit_route()
  local choice = {
    kind = "unknown_type",
    meta = { some_field = true },
  }
  _assert_eq(policy.resolve(choice), "base_inline", "choice without route metadata should fall back to base_inline")
end

-- ── policy.requires_confirm: explicit confirm chain ───────────────

function TestRoutePolicy:test_requires_confirm_returns_explicit_from_choice_body()
  local choice = {
    kind = "tax_card_prompt",
    requires_confirm = true,
    route_key = "secondary_confirm",
  }
  _assert_eq(policy.requires_confirm(choice), true, "explicit requires_confirm on body should be returned")
end

function TestRoutePolicy:test_requires_confirm_returns_explicit_from_choice_body_false()
  local choice = {
    kind = "item_target_player",
    requires_confirm = false,
    route_key = "player",
  }
  _assert_eq(policy.requires_confirm(choice), false, "explicit requires_confirm=false on body should be returned")
end

function TestRoutePolicy:test_requires_confirm_returns_explicit_from_route_field()
  local choice = {
    kind = "landing_optional_effect",
    route = { requires_confirm = true, route_key = "secondary_confirm" },
  }
  _assert_eq(policy.requires_confirm(choice), true,
    "requires_confirm on choice.route should be returned")
end

function TestRoutePolicy:test_requires_confirm_returns_explicit_from_meta()
  local choice = {
    kind = "market_purchase",
    meta = { requires_confirm = true, route_key = "secondary_confirm" },
  }
  _assert_eq(policy.requires_confirm(choice), true,
    "requires_confirm on choice.meta should be returned")
end

-- ── policy.requires_confirm: fallback to route resolution ─────────

function TestRoutePolicy:test_requires_confirm_returns_true_when_fallback_route_is_secondary_confirm()
  local choice = {
    kind = "buy_land_prompt",
    route_key = "secondary_confirm",
  }
  _assert_eq(policy.requires_confirm(choice), true,
    "fallback route='secondary_confirm' should imply confirm=true")
end

function TestRoutePolicy:test_requires_confirm_returns_false_when_fallback_route_is_not_secondary_confirm()
  local choice = {
    kind = "item_target_player",
    route_key = "player",
  }
  _assert_eq(policy.requires_confirm(choice), false,
    "fallback route='player' should not require confirm")
end

-- ── policy.requires_confirm: string input ─────────────────────────

function TestRoutePolicy:test_requires_confirm_returns_true_for_string_secondary_confirm()
  _assert_eq(policy.requires_confirm("secondary_confirm"), true,
    "string 'secondary_confirm' should require confirm")
end

function TestRoutePolicy:test_requires_confirm_returns_false_for_string_not_secondary_confirm()
  _assert_eq(policy.requires_confirm("base_inline"), false,
    "string 'base_inline' should not require confirm")
end

-- ── policy.requires_confirm: nil and non-table ────────────────────

function TestRoutePolicy:test_requires_confirm_returns_false_for_nil()
  _assert_eq(policy.requires_confirm(nil), false, "nil should return false")
end

function TestRoutePolicy:test_requires_confirm_returns_false_for_boolean_input()
  _assert_eq(policy.requires_confirm(true), false, "boolean true should return false")
end

-- ── policy.is_screenless_route ────────────────────────────────────

function TestRoutePolicy:test_is_screenless_route_true_for_base_inline()
  _assert_eq(policy.is_screenless_route("base_inline"), true, "base_inline should be screenless")
end

function TestRoutePolicy:test_is_screenless_route_true_for_item_phase_passive()
  _assert_eq(policy.is_screenless_route("item_phase_passive"), true,
    "item_phase_passive should be screenless")
end

function TestRoutePolicy:test_is_screenless_route_false_for_normal_route()
  _assert_eq(policy.is_screenless_route("player"), false, "player route should not be screenless")
end

-- ── policy.is_secondary_confirm_choice ────────────────────────────

function TestRoutePolicy:test_is_secondary_confirm_choice_returns_true()
  local choice = { kind = "tax_card_prompt", route_key = "secondary_confirm" }
  _assert_eq(policy.is_secondary_confirm_choice(choice), true,
    "secondary_confirm route should be detected")
end

function TestRoutePolicy:test_is_secondary_confirm_choice_returns_false_for_different_route()
  local choice = { kind = "item_target_player", route_key = "player" }
  _assert_eq(policy.is_secondary_confirm_choice(choice), false,
    "non-secondary_confirm route should not match")
end

-- ── _non_empty_route_key edge via _resolve_explicit_route ─────────

function TestRoutePolicy:test_resolve_skips_empty_route_key()
  local choice = {
    kind = "test",
    route_key = "",
    meta = { route_key = "market" },
  }
  _assert_eq(policy.resolve(choice), "market",
    "empty route_key on body should be skipped, falling through to meta")
end

-- ── _boolean_field: non-table / non-boolean holder ────────────────
-- exercised through requires_confirm with a choice that has a non-table route or meta.

function TestRoutePolicy:test_requires_confirm_ignores_non_table_route_field()
  local choice = {
    kind = "test",
    route = "not-a-table",
    route_key = "secondary_confirm",
  }
  -- route is a string, not a table → _boolean_field returns nil → falls through to meta → meta is nil → falls through to resolve → secondary_confirm → true
  _assert_eq(policy.requires_confirm(choice), true,
    "non-table route field should be skipped, falling through to route resolution")
end

function TestRoutePolicy:test_requires_confirm_ignores_non_boolean_field_on_body()
  local choice = {
    kind = "test",
    requires_confirm = "yes", -- non-boolean
    route_key = "secondary_confirm",
  }
  -- requires_confirm field is a string not boolean → _boolean_field returns nil → falls through
  _assert_eq(policy.requires_confirm(choice), true,
    "non-boolean requires_confirm field should be skipped, falling through to route")
end

-- ── requires_confirm with explicit field on non-secondary route ───
-- These force the explicit field to return a value that differs from
-- the route-resolution fallback, exercising _boolean_field and
-- _resolve_explicit_requires_confirm branch arms individually.

function TestRoutePolicy:test_requires_confirm_reads_explicit_true_from_body_against_non_secondary_route()
  local choice = { kind = "test", requires_confirm = true, route_key = "player" }
  _assert_eq(policy.requires_confirm(choice), true,
    "explicit requires_confirm=true on body overrides non-secondary route fallback")
end

function TestRoutePolicy:test_requires_confirm_reads_explicit_false_from_body_against_secondary_route()
  local choice = { kind = "test", requires_confirm = false, route_key = "secondary_confirm" }
  _assert_eq(policy.requires_confirm(choice), false,
    "explicit requires_confirm=false on body overrides secondary_confirm route fallback")
end

function TestRoutePolicy:test_requires_confirm_reads_explicit_true_from_route_field_on_non_secondary_route()
  local choice = { kind = "test", route_key = "player", route = { requires_confirm = true } }
  _assert_eq(policy.requires_confirm(choice), true,
    "explicit requires_confirm=true on route field overrides non-secondary route resolution")
end

function TestRoutePolicy:test_requires_confirm_reads_explicit_false_from_route_field_on_secondary_route()
  local choice = { kind = "test", route_key = "secondary_confirm", route = { requires_confirm = false } }
  _assert_eq(policy.requires_confirm(choice), false,
    "explicit requires_confirm=false on route field overrides secondary_confirm route resolution")
end

function TestRoutePolicy:test_requires_confirm_reads_explicit_true_from_meta_on_non_secondary_route()
  local choice = { kind = "test", route_key = "player", meta = { requires_confirm = true } }
  _assert_eq(policy.requires_confirm(choice), true,
    "explicit requires_confirm=true on meta overrides non-secondary route resolution")
end

function TestRoutePolicy:test_requires_confirm_reads_explicit_false_from_meta_on_secondary_route()
  local choice = { kind = "test", route_key = "secondary_confirm", meta = { requires_confirm = false } }
  _assert_eq(policy.requires_confirm(choice), false,
    "explicit requires_confirm=false on meta overrides secondary_confirm route resolution")
end


return TestRoutePolicy
