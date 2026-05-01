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







-- validate_choice_actor





-- validate_choice_id






-- validate_choice_action





-- _resolve_item_slot_resolution







-- resolve_item_slot_action (public wrapper)



-- _resolve_item_slot_resolution: item allowed by availability (line 95 path)


-- _resolve_item_slot_resolution: item denied by availability


-- resolve_gate_state: without ui_sync_ports


-- resolve_gate_state: with ui_sync_ports providing gate data


-- should_block_action: input blocked → blocks turn-bound action

describe("domain validator coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("validate_actor_role non-turn-bound action returns true", function()
    local game = _make_game_with_player(1001)
    _assert_eq(validator.validate_actor_role(game, { id = "buy", actor_role_id = 1002 }), true,
      "non-turn-bound action should always return true")
  end)

  it("validate_actor_role next matching actor returns true", function()
    local game = _make_game_with_player(1001)
    _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1001 }), true,
      "'next' with matching actor should return true")
  end)

  it("validate_actor_role next nil actor_role_id returns false", function()
    local game = _make_game_with_player(1001)
    _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = nil }), false,
      "'next' with nil actor_role_id should return false")
  end)

  it("validate_actor_role next nil current player returns false", function()
    local game = { turn = { current_player_index = 1 }, players = {} }
    _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1001 }), false,
      "'next' with missing current player should return false")
  end)

  it("validate_actor_role next wrong actor returns false", function()
    local game = _make_game_with_player(1001)
    _assert_eq(validator.validate_actor_role(game, { id = "next", actor_role_id = 1002 }), false,
      "'next' with wrong actor should return false")
  end)

  it("validate_actor_role item_slot matching actor returns true", function()
    local game = _make_game_with_player(1001)
    _assert_eq(validator.validate_actor_role(game, { id = "item_slot_2", actor_role_id = 1001 }), true,
      "item_slot button with matching actor should return true")
  end)

  it("validate_choice_actor nil actor returns false", function()
    local game = {}
    local choice = { id = 10, kind = "market_buy" }
    _assert_eq(validator.validate_choice_actor(game, { actor_role_id = nil }, choice), false,
      "nil actor_role_id should return false")
  end)

  it("validate_choice_actor nil owner allows any actor", function()
    local game = {}
    local choice = { id = 10, kind = "market_buy" }
    _assert_eq(validator.validate_choice_actor(game, { actor_role_id = 1001 }, choice), true,
      "nil owner_role_id should accept any actor")
  end)

  it("validate_choice_actor matching owner returns true", function()
    local game = {}
    local choice = { id = 10, kind = "market_buy", owner_role_id = 1001 }
    _assert_eq(validator.validate_choice_actor(game, { actor_role_id = 1001 }, choice), true,
      "matching owner_role_id should return true")
  end)

  it("validate_choice_actor wrong owner returns false", function()
    local game = {}
    local choice = { id = 10, kind = "market_buy", owner_role_id = 1001 }
    _assert_eq(validator.validate_choice_actor(game, { actor_role_id = 1002 }, choice), false,
      "wrong owner_role_id should return false")
  end)

  it("validate_choice_id nil action returns false", function()
    _assert_eq(validator.validate_choice_id(nil, { id = 10 }), false,
      "nil action should return false")
  end)

  it("validate_choice_id nil choice returns false", function()
    _assert_eq(validator.validate_choice_id({ choice_id = 10 }, nil), false,
      "nil choice should return false")
  end)

  it("validate_choice_id matching id returns true", function()
    _assert_eq(validator.validate_choice_id({ choice_id = 10 }, { id = 10 }), true,
      "matching choice_id should return true")
  end)

  it("validate_choice_id mismatched id returns false", function()
    _assert_eq(validator.validate_choice_id({ choice_id = 10 }, { id = 99 }), false,
      "mismatched choice_id should return false")
  end)

  it("validate_choice_id nil action.choice_id returns false", function()
    _assert_eq(validator.validate_choice_id({ choice_id = nil }, { id = 10 }), false,
      "nil action.choice_id should return false")
  end)

  it("validate_choice_action nil choice returns false", function()
    _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, nil), false,
      "nil choice should return false")
  end)

  it("validate_choice_action choice without id returns false", function()
    _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, {}), false,
      "choice without id should return false")
  end)

  it("validate_choice_action actor mismatch returns false", function()
    local choice = { id = 10, owner_role_id = 1001 }
    _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1002, choice_id = 10 }, choice), false,
      "wrong actor should return false")
  end)

  it("validate_choice_action success", function()
    local choice = { id = 10, owner_role_id = 1001 }
    _assert_eq(validator.validate_choice_action({}, { actor_role_id = 1001, choice_id = 10 }, choice), true,
      "valid actor and choice_id should return true")
  end)

  it("item_slot_resolution invalid action id", function()
    local result = validator._resolve_item_slot_resolution(nil, {}, { id = "next" }, nil)
    _assert_eq(result.ok, false, "non-item_slot action should fail")
    _assert_eq(result.reason, "invalid_action", "reason should be invalid_action")
  end)

  it("item_slot_resolution missing choice", function()
    local result = validator._resolve_item_slot_resolution(nil, {}, { id = "item_slot_1" }, nil)
    _assert_eq(result.ok, false, "missing choice should fail")
    _assert_eq(result.reason, "missing_choice", "reason should be missing_choice")
  end)

  it("item_slot_resolution missing item_id", function()
    local state = {}
    local choice = { id = 5, kind = "item_phase_choice", options = { "item_a" } }
    runtime_state.set_pending_choice(state, choice)
    local source = {
      resolve_slot_action = function() return nil end,
    }
    local result = validator._resolve_item_slot_resolution(source, state, { id = "item_slot_1", actor_role_id = 1001 }, nil)
    _assert_eq(result.ok, false, "missing item_id should fail")
    _assert_eq(result.reason, "missing_item_id", "reason should be missing_item_id")
  end)

  it("item_slot_resolution invalid item option", function()
    local state = {}
    local choice = { id = 5, kind = "item_phase_choice", options = { "item_a" } }
    runtime_state.set_pending_choice(state, choice)
    local source = {
      resolve_slot_action = function() return "item_not_in_options" end,
    }
    local result = validator._resolve_item_slot_resolution(source, state, { id = "item_slot_1", actor_role_id = 1001 }, nil)
    _assert_eq(result.ok, false, "item not in options should fail")
    _assert_eq(result.reason, "invalid_item_option", "reason should be invalid_item_option")
  end)

  it("item_slot_resolution success", function()
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
  end)

  it("item_slot_resolution choice from game.turn", function()
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
  end)

  it("resolve_item_slot_action returns nil on invalid_action", function()
    local result = validator.resolve_item_slot_action(nil, {}, { id = "buy" }, nil)
    _assert_eq(result, nil, "invalid_action should return nil")
  end)

  it("resolve_item_slot_action returns not-ok on other errors", function()
    local result = validator.resolve_item_slot_action(nil, {}, { id = "item_slot_1" }, nil)
    assert(result ~= nil, "non-invalid_action error should not return nil")
    _assert_eq(result.ok, false, "missing_choice should return {ok=false}")
  end)

  it("item_slot_resolution allowed by availability", function()
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
  end)

  it("item_slot_resolution denied by availability", function()
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
  end)

  it("resolve_gate_state without ports", function()
    local state = { game = { turn = { phase = "land" } } }
    local gate = validator.resolve_gate_state(state, nil)
    assert(type(gate) == "table", "should return gate table")
    _assert_eq(gate.phase, "land", "phase should be from game.turn")
    _assert_eq(gate.input_blocked, false, "input_blocked defaults to false")
    _assert_eq(gate.choice_active, false, "choice_active defaults to false")
    _assert_eq(gate.detained_wait_active, false, "detained_wait_active defaults to false")
  end)

  it("resolve_gate_state with ports", function()
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
  end)

  it("should_block_action blocked when input blocked", function()
    local result = validator.should_block_action(true, "choice_select")
    _assert_eq(result, true, "true gate_state should block choice_select action")
  end)

  it("should_block_action passes when not blocked", function()
    local result = validator.should_block_action(false, "choice_select")
    _assert_eq(result, false, "false gate_state should not block")
  end)
end)
