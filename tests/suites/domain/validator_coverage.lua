local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.runtime_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game_with_player(role_id, current_index)
  current_index = current_index or 1
  return {
    turn = {
      current_player_index = current_index,
    },
    players = {
      [current_index] = { id = role_id },
    },
  }
end

-- validate_actor_role

local function test_validate_actor_role_non_turn_bound_action_returns_true()
  local game = _make_game_with_player(1001)
  _assert_eq(validator.validate_actor_role(game, { id = "buy", actor_role_id = 1002 }), true,
    "non-turn-bound action should always return true")
end

local function test_validate_actor_role_next_matching_actor_returns_true()
  local game = _make_game_with_player(1001)
  _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1001 }), true,
    "'next' with matching actor should return true")
end

local function test_validate_actor_role_next_nil_actor_role_id_returns_false()
  local game = _make_game_with_player(1001)
  _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = nil }), false,
    "'next' with nil actor_role_id should return false")
end

local function test_validate_actor_role_next_nil_current_player_returns_false()
  local game = { turn = { current_player_index = 1 }, players = {} }
  _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1001 }), false,
    "'next' with missing current player should return false")
end

local function test_validate_actor_role_next_wrong_actor_returns_false()
  local game = _make_game_with_player(1001)
  _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1002 }), false,
    "'next' with wrong actor should return false")
end

local function test_validate_actor_role_item_slot_matching_actor_returns_true()
  local game = _make_game_with_player(1001)
  _assert_eq(validator.validate_actor_role(game, { id = "item_slot_2", actor_role_id = 1001 }), true,
    "item_slot button with matching actor should return true")
end

-- validate_choice_actor

local function test_validate_choice_actor_nil_actor_returns_false()
  local game = {}
  local choice = { id = 10, kind = "market_buy" }
  _assert_eq(validator.validate_choice_actor(game, { actor_role_id = nil }, choice), false,
    "nil actor_role_id should return false")
end

local function test_validate_choice_actor_nil_owner_allows_any_actor()
  local game = {}
  local choice = { id = 10, kind = "market_buy" }
  _assert_eq(validator.validate_choice_actor(game, { actor_role_id = 1001 }, choice), true,
    "nil owner_role_id should accept any actor")
end

local function test_validate_choice_actor_matching_owner_returns_true()
  local game = {}
  local choice = { id = 10, kind = "market_buy", owner_role_id = 1001 }
  _assert_eq(validator.validate_choice_actor(game, { actor_role_id = 1001 }, choice), true,
    "matching owner_role_id should return true")
end

local function test_validate_choice_actor_wrong_owner_returns_false()
  local game = {}
  local choice = { id = 10, kind = "market_buy", owner_role_id = 1001 }
  _assert_eq(validator.validate_choice_actor(game, { actor_role_id = 1002 }, choice), false,
    "wrong owner_role_id should return false")
end

-- validate_choice_id

local function test_validate_choice_id_nil_action_returns_false()
  _assert_eq(validator.validate_choice_id(nil, { id = 10 }), false,
    "nil action should return false")
end

local function test_validate_choice_id_nil_choice_returns_false()
  _assert_eq(validator.validate_choice_id({ choice_id = 10 }, nil), false,
    "nil choice should return false")
end

local function test_validate_choice_id_matching_id_returns_true()
  _assert_eq(validator.validate_choice_id({ choice_id = 10 }, { id = 10 }), true,
    "matching choice_id should return true")
end

local function test_validate_choice_id_mismatched_id_returns_false()
  _assert_eq(validator.validate_choice_id({ choice_id = 10 }, { id = 99 }), false,
    "mismatched choice_id should return false")
end

local function test_validate_choice_id_nil_action_choice_id_returns_false()
  _assert_eq(validator.validate_choice_id({ choice_id = nil }, { id = 10 }), false,
    "nil action.choice_id should return false")
end

-- validate_choice_action

local function test_validate_choice_action_nil_choice_returns_false()
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, nil), false,
    "nil choice should return false")
end

local function test_validate_choice_action_choice_without_id_returns_false()
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, {}), false,
    "choice without id should return false")
end

local function test_validate_choice_action_actor_mismatch_returns_false()
  local choice = { id = 10, owner_role_id = 1001 }
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1002, choice_id = 10 }, choice), false,
    "wrong actor should return false")
end

local function test_validate_choice_action_success()
  local choice = { id = 10, owner_role_id = 1001 }
  _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, choice), true,
    "valid actor and choice_id should return true")
end

-- _resolve_item_slot_resolution

local function test_item_slot_resolution_invalid_action_id()
  local result = validator._resolve_item_slot_resolution(nil, {}, { id = "next" }, nil)
  _assert_eq(result.ok, false, "non-item_slot action should fail")
  _assert_eq(result.reason, "invalid_action", "reason should be invalid_action")
end

local function test_item_slot_resolution_missing_choice()
  local result = validator._resolve_item_slot_resolution(nil, {}, { id = "item_slot_1" }, nil)
  _assert_eq(result.ok, false, "missing choice should fail")
  _assert_eq(result.reason, "missing_choice", "reason should be missing_choice")
end

local function test_item_slot_resolution_missing_item_id()
  local state = {}
  local choice = { id = 5, kind = "item_phase_choice", options = { "item_a" } }
  runtime_state.set_pending_choice(state, choice)
  local source = {
    resolve_slot_action = function() return nil end,
  }
  local result = validator._resolve_item_slot_resolution(source, state, { id = "item_slot_1", actor_role_id = 1001 }, nil)
  _assert_eq(result.ok, false, "missing item_id should fail")
  _assert_eq(result.reason, "missing_item_id", "reason should be missing_item_id")
end

local function test_item_slot_resolution_invalid_item_option()
  local state = {}
  local choice = { id = 5, kind = "item_phase_choice", options = { "item_a" } }
  runtime_state.set_pending_choice(state, choice)
  local source = {
    resolve_slot_action = function() return "item_not_in_options" end,
  }
  local result = validator._resolve_item_slot_resolution(source, state, { id = "item_slot_1", actor_role_id = 1001 }, nil)
  _assert_eq(result.ok, false, "item not in options should fail")
  _assert_eq(result.reason, "invalid_item_option", "reason should be invalid_item_option")
end

local function test_item_slot_resolution_success()
  local state = {}
  local choice = { id = 5, kind = "item_phase_choice", options = { "item_a" } }
  runtime_state.set_pending_choice(state, choice)
  local source = {
    resolve_slot_action = function() return "item_a" end,
  }
  local result = validator._resolve_item_slot_resolution(
    source, state, { id = "item_slot_1", actor_role_id = 1001, input_source = "touch" }, nil
  )
  _assert_eq(result.ok, true, "valid item slot action should succeed")
  assert(type(result.action) == "table", "success should include action")
  _assert_eq(result.action.type, "choice_select", "action type should be choice_select")
  _assert_eq(result.action.option_id, "item_a", "option_id should be item_a")
end

local function test_item_slot_resolution_choice_from_game_turn()
  local state = {}
  local choice = { id = 7, kind = "item_phase_choice", options = { "item_b" } }
  local game = { turn = { pending_choice = choice } }
  local source = {
    resolve_slot_action = function() return "item_b" end,
  }
  local result = validator._resolve_item_slot_resolution(
    source, state, { id = "item_slot_1", actor_role_id = 1001 }, game
  )
  _assert_eq(result.ok, true, "choice from game.turn should work")
end

-- resolve_item_slot_action (public wrapper)

local function test_resolve_item_slot_action_returns_nil_on_invalid_action()
  local result = validator.resolve_item_slot_action(nil, {}, { id = "buy" }, nil)
  _assert_eq(result, nil, "invalid_action should return nil")
end

local function test_resolve_item_slot_action_returns_not_ok_on_other_errors()
  local result = validator.resolve_item_slot_action(nil, {}, { id = "item_slot_1" }, nil)
  assert(result ~= nil, "non-invalid_action error should not return nil")
  _assert_eq(result.ok, false, "missing_choice should return {ok=false}")
end

-- _resolve_item_slot_resolution: item allowed by availability (line 95 path)

local function test_item_slot_resolution_allowed_by_availability()
  local state = {}
  local choice = {
    id = 5,
    kind = "item_phase_choice",
    options = { "item_a" },
    meta = { phase = "pre_action" },
  }
  runtime_state.set_pending_choice(state, choice)
  local source = {
    resolve_slot_action = function() return "item_a" end,
  }
  local avail_mod = require("src.rules.items.availability")
  local saved = avail_mod.can_offer_in_phase
  avail_mod.can_offer_in_phase = function() return true end
  local game = {
    find_player_by_id = function(_, _) return { id = 1001 } end,
  }
  local result = validator._resolve_item_slot_resolution(
    source, state, { id = "item_slot_1", actor_role_id = 1001 }, game
  )
  avail_mod.can_offer_in_phase = saved
  _assert_eq(result.ok, true, "availability allowed should return ok=true")
end

-- _resolve_item_slot_resolution: item denied by availability

local function test_item_slot_resolution_denied_by_availability()
  local state = {}
  local choice = {
    id = 5,
    kind = "item_phase_choice",
    options = { "item_a" },
    meta = { phase = "items" },
  }
  runtime_state.set_pending_choice(state, choice)
  local source = {
    resolve_slot_action = function() return "item_a" end,
  }
  local availability_override = require("src.rules.items.availability")
  local saved = availability_override.can_offer_in_phase
  availability_override.can_offer_in_phase = function() return false end
  local game = {
    find_player_by_id = function(_, _) return { id = 1001 } end,
  }
  local result = validator._resolve_item_slot_resolution(
    source, state, { id = "item_slot_1", actor_role_id = 1001 }, game
  )
  availability_override.can_offer_in_phase = saved
  _assert_eq(result.ok, false, "availability denial should return ok=false")
  _assert_eq(result.reason, "item_slot_denied_by_availability", "reason should be item_slot_denied_by_availability")
end

-- resolve_gate_state: without ui_sync_ports

local function test_resolve_gate_state_without_ports()
  local state = { game = { turn = { phase = "land" } } }
  local gate = validator.resolve_gate_state(state, nil)
  assert(type(gate) == "table", "should return gate table")
  _assert_eq(gate.phase, "land", "phase should be from game.turn")
  _assert_eq(gate.input_blocked, false, "input_blocked defaults to false")
  _assert_eq(gate.choice_active, false, "choice_active defaults to false")
  _assert_eq(gate.detained_wait_active, false, "detained_wait_active defaults to false")
end

-- resolve_gate_state: with ui_sync_ports providing gate data

local function test_resolve_gate_state_with_ports()
  local state = {}
  local ui_sync_ports = {
    resolve_ui_gate = function(_)
      return { input_blocked = true, choice_active = true, market_active = false, popup_active = true }
    end,
  }
  local gate = validator.resolve_gate_state(state, ui_sync_ports)
  _assert_eq(gate.input_blocked, true, "input_blocked from ui_gate should be true")
  _assert_eq(gate.choice_active, true, "choice_active from ui_gate should be true")
  _assert_eq(gate.popup_active, true, "popup_active from ui_gate should be true")
end

-- should_block_action: input blocked → blocks turn-bound action

local function test_should_block_action_blocked_when_input_blocked()
  local result = validator.should_block_action(true, "choice_select")
  _assert_eq(result, true, "true gate_state should block choice_select action")
end

local function test_should_block_action_passes_when_not_blocked()
  local result = validator.should_block_action(false, "choice_select")
  _assert_eq(result, false, "false gate_state should not block")
end

return {
  name = "domain validator coverage",
  tests = {
    { name = "validate_actor_role non-turn-bound action returns true", run = test_validate_actor_role_non_turn_bound_action_returns_true },
    { name = "validate_actor_role next matching actor returns true", run = test_validate_actor_role_next_matching_actor_returns_true },
    { name = "validate_actor_role next nil actor_role_id returns false", run = test_validate_actor_role_next_nil_actor_role_id_returns_false },
    { name = "validate_actor_role next nil current player returns false", run = test_validate_actor_role_next_nil_current_player_returns_false },
    { name = "validate_actor_role next wrong actor returns false", run = test_validate_actor_role_next_wrong_actor_returns_false },
    { name = "validate_actor_role item_slot matching actor returns true", run = test_validate_actor_role_item_slot_matching_actor_returns_true },
    { name = "validate_choice_actor nil actor returns false", run = test_validate_choice_actor_nil_actor_returns_false },
    { name = "validate_choice_actor nil owner allows any actor", run = test_validate_choice_actor_nil_owner_allows_any_actor },
    { name = "validate_choice_actor matching owner returns true", run = test_validate_choice_actor_matching_owner_returns_true },
    { name = "validate_choice_actor wrong owner returns false", run = test_validate_choice_actor_wrong_owner_returns_false },
    { name = "validate_choice_id nil action returns false", run = test_validate_choice_id_nil_action_returns_false },
    { name = "validate_choice_id nil choice returns false", run = test_validate_choice_id_nil_choice_returns_false },
    { name = "validate_choice_id matching id returns true", run = test_validate_choice_id_matching_id_returns_true },
    { name = "validate_choice_id mismatched id returns false", run = test_validate_choice_id_mismatched_id_returns_false },
    { name = "validate_choice_id nil action.choice_id returns false", run = test_validate_choice_id_nil_action_choice_id_returns_false },
    { name = "validate_choice_action nil choice returns false", run = test_validate_choice_action_nil_choice_returns_false },
    { name = "validate_choice_action choice without id returns false", run = test_validate_choice_action_choice_without_id_returns_false },
    { name = "validate_choice_action actor mismatch returns false", run = test_validate_choice_action_actor_mismatch_returns_false },
    { name = "validate_choice_action success", run = test_validate_choice_action_success },
    { name = "item_slot_resolution invalid action id", run = test_item_slot_resolution_invalid_action_id },
    { name = "item_slot_resolution missing choice", run = test_item_slot_resolution_missing_choice },
    { name = "item_slot_resolution missing item_id", run = test_item_slot_resolution_missing_item_id },
    { name = "item_slot_resolution invalid item option", run = test_item_slot_resolution_invalid_item_option },
    { name = "item_slot_resolution success", run = test_item_slot_resolution_success },
    { name = "item_slot_resolution choice from game.turn", run = test_item_slot_resolution_choice_from_game_turn },
    { name = "resolve_item_slot_action returns nil on invalid_action", run = test_resolve_item_slot_action_returns_nil_on_invalid_action },
    { name = "resolve_item_slot_action returns not-ok on other errors", run = test_resolve_item_slot_action_returns_not_ok_on_other_errors },
    { name = "item_slot_resolution allowed by availability", run = test_item_slot_resolution_allowed_by_availability },
    { name = "item_slot_resolution denied by availability", run = test_item_slot_resolution_denied_by_availability },
    { name = "resolve_gate_state without ports", run = test_resolve_gate_state_without_ports },
    { name = "resolve_gate_state with ports", run = test_resolve_gate_state_with_ports },
    { name = "should_block_action blocked when input blocked", run = test_should_block_action_blocked_when_input_blocked },
    { name = "should_block_action passes when not blocked", run = test_should_block_action_passes_when_not_blocked },
  },
}
