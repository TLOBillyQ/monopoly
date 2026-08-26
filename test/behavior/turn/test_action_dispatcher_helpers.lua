local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local helpers = require("src.turn.actions.action_dispatcher_helpers")

TestActionDispatcherHelpers = {}

-- should_invalidate_ui 覆盖（杀掉 INVALIDATING_ACTION_TYPES 表内 true→false 幸存者）

function TestActionDispatcherHelpers:test_should_invalidate_ui_for_complete_optional_action_phase()
  _assert_eq(helpers.should_invalidate_ui({ type = "complete_optional_action_phase" }), true,
    "complete_optional_action_phase should invalidate UI")
end

function TestActionDispatcherHelpers:test_should_invalidate_ui_for_choice_cancel()
  _assert_eq(helpers.should_invalidate_ui({ type = "choice_cancel" }), true,
    "choice_cancel should invalidate UI")
end

function TestActionDispatcherHelpers:test_should_invalidate_ui_for_unknown_type()
  _assert_eq(helpers.should_invalidate_ui({ type = "unknown_action" }), false,
    "unknown action type should not invalidate UI")
end

-- allows_market_cancel_while_blocked 覆盖（杀掉 _blocked_gate / _cancel_action /
-- _same_choice 内部 and→or 以及 return false→true 幸存者）

function TestActionDispatcherHelpers:test_allows_market_cancel_blocked_gate_nil()
  local result = helpers.allows_market_cancel_while_blocked(
    nil,
    { turn = {} },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "nil gate_state should not allow market cancel")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_gate_not_blocked()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = false },
    { turn = {} },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "unblocked gate should not allow market cancel")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_not_cancel_action()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = {} },
    {},
    { type = "ui_button", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "non-cancel action through blocked gate should not be allowed")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_not_cancel_action_with_matching_pending()
  -- 非 cancel action 即使与 market_buy pending choice 同 id 也不允许通过
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = { id = "c1", kind = "market_buy" } } },
    {},
    { type = "ui_button", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "non-cancel action should not be allowed even with matching pending choice")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_no_pending_choice()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = nil } },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "blocked gate + cancel action but no pending choice should not allow")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_pending_not_market_buy()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = { id = "c1", kind = "item_phase_passive" } } },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "blocked gate + cancel action + non-market pending choice should not allow")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_different_choice_id()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = { id = "c2", kind = "market_buy" } } },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "different choice_id should not match")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_same_choice_id()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = { id = "c1", kind = "market_buy" } } },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, true, "blocked gate + cancel action + matching market_buy pending choice should allow")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_choice_id_nil_in_action()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = { id = "c1", kind = "market_buy" } } },
    {},
    { type = "choice_cancel" },
    {}
  )
  _assert_eq(result, false, "action without choice_id should not match even with same pending choice id")
end

function TestActionDispatcherHelpers:test_allows_market_cancel_choice_id_nil_in_pending()
  local result = helpers.allows_market_cancel_while_blocked(
    { input_blocked = true },
    { turn = { pending_choice = { kind = "market_buy" } } },
    {},
    { type = "choice_cancel", choice_id = "c1" },
    {}
  )
  _assert_eq(result, false, "pending choice without id should not match")
end

return TestActionDispatcherHelpers
