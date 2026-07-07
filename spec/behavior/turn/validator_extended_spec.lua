local validator = require("src.turn.actions.validator")
local runtime_state = require("src.state.runtime")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _item_phase_state(choice)
  local state = {}
  runtime_state.set_pending_choice(state, choice)
  return state
end

local function _slot_source(item_id)
  return { resolve_slot_action = function() return item_id end }
end

describe("domain validator extended coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("validate_choice_action with nil action returns false (via missing actor)", function()
    local choice = { id = 10, kind = "market_buy" }
    _assert_eq(
      validator.validate_choice_action({}, nil, choice),
      false, "nil action should fail validate_choice_actor (no actor)"
    )
  end)

  it("validate_choice_actor with nil action returns false", function()
    _assert_eq(
      validator.validate_choice_actor({}, nil, { id = 10 }),
      false, "nil action should return false"
    )
  end)

  it("validate_choice_actor uses current player when choice has no owner_role_id", function()
    local game = {
      current_player = function() return { id = 1001 } end,
    }
    local choice = { id = 10, kind = "market_buy" }
    _assert_eq(
      validator.validate_choice_actor(game, { actor_role_id = 1001 }, choice),
      true, "actor matching current_player should pass when no owner_role_id"
    )
    _assert_eq(
      validator.validate_choice_actor(game, { actor_role_id = 1002 }, choice),
      false, "actor not matching current_player should fail"
    )
  end)

  it("item slot resolution recognizes item_phase_passive choice kind", function()
    local state = _item_phase_state({ id = 7, kind = "item_phase_passive", options = { "item_x" } })
    local result = validator.resolve_item_slot_action(
      _slot_source("item_x"), state, { id = "item_slot_1", actor_role_id = 1001 }, nil
    )
    _assert_eq(result.ok, true, "item_phase_passive should be a valid kind")
  end)

  it("validate refuses item slots against a non-item-phase choice with missing_choice", function()
    local state = _item_phase_state({ id = 8, kind = "market_buy", options = { "anything" } })
    local game = {
      turn = { current_player_index = 1 },
      players = { [1] = { id = 1001 } },
    }
    local ok, reason = validator.validate(
      { type = "ui_button", id = "item_slot_1", actor_role_id = 1001 },
      { game = game, state = state, item_slot_source = _slot_source("anything") }
    )
    _assert_eq(ok, false, "non-item-phase choice should fail")
    _assert_eq(reason, "missing_choice", "reason should be missing_choice")
  end)

  it("item slot availability check skips when actor is nil", function()
    local state = _item_phase_state({
      id = 9,
      kind = "item_phase_choice",
      options = { "item_a" },
      meta = { phase = "items" },
    })
    local game = { find_player_by_id = function() return nil end }
    local result = validator.resolve_item_slot_action(
      _slot_source("item_a"), state, { id = "item_slot_1", actor_role_id = 1001 }, game
    )
    _assert_eq(result.ok, true, "missing actor should bypass availability check")
  end)

  it("item slot availability check skips when meta phase is empty", function()
    local state = _item_phase_state({
      id = 11,
      kind = "item_phase_choice",
      options = { "item_a" },
      meta = { phase = "" },
    })
    local game = { find_player_by_id = function() return { id = 1001 } end }
    local result = validator.resolve_item_slot_action(
      _slot_source("item_a"), state, { id = "item_slot_1", actor_role_id = 1001 }, game
    )
    _assert_eq(result.ok, true, "empty phase string should bypass availability check")
  end)

  it("item slot availability check skips when no meta", function()
    local state = _item_phase_state({
      id = 12,
      kind = "item_phase_choice",
      options = { "item_a" },
    })
    local game = { find_player_by_id = function() return { id = 1001 } end }
    local result = validator.resolve_item_slot_action(
      _slot_source("item_a"), state, { id = "item_slot_1", actor_role_id = 1001 }, game
    )
    _assert_eq(result.ok, true, "no meta should bypass availability check (phase is nil)")
  end)

  it("item slot resolution uses state.game when game arg is nil", function()
    local state = {}
    local choice = { id = 13, kind = "item_phase_choice", options = { "item_a" } }
    state.game = { turn = { pending_choice = nil }, find_player_by_id = function() return nil end }
    runtime_state.set_pending_choice(state, choice)
    local result = validator.resolve_item_slot_action(
      _slot_source("item_a"), state, { id = "item_slot_1", actor_role_id = 1001 }, nil
    )
    _assert_eq(result.ok, true, "should resolve runtime_game via state.game when game arg is nil")
  end)

  it("item slot resolution carries action input_source into resolved choice_select", function()
    local state = _item_phase_state({ id = 14, kind = "item_phase_choice", options = { "item_a" } })
    local result = validator.resolve_item_slot_action(
      _slot_source("item_a"), state, {
        id = "item_slot_1",
        actor_role_id = 1001,
        input_source = "remote_pick",
      }, nil
    )
    _assert_eq(result.ok, true, "should succeed")
    _assert_eq(result.action.input_source, "remote_pick", "input_source should be carried through")
    _assert_eq(result.action.actor_role_id, 1001, "actor_role_id should be carried through")
    _assert_eq(result.action.choice_id, 14, "choice_id should be carried through")
  end)

  it("validate_actor_role with item_slot_X non-matching role returns false", function()
    local game = {
      turn = { current_player_index = 1 },
      players = { [1] = { id = 1001 } },
    }
    _assert_eq(
      validator.validate_actor_role(game, { id = "item_slot_3", actor_role_id = 9999 }),
      false, "item_slot_X with non-matching role should return false"
    )
  end)

  it("resolve_gate_state derives detained_wait_active from game.turn", function()
    local state = { game = { turn = { phase = "land", detained_wait_active = true } } }
    local gate = validator.resolve_gate_state(state, nil)
    _assert_eq(gate.detained_wait_active, true, "detained_wait_active should be exposed")
    _assert_eq(gate.phase, "land", "phase should be passed through")
  end)

  it("resolve_gate_state with no game returns empty-phase gate", function()
    local gate = validator.resolve_gate_state({}, nil)
    _assert_eq(gate.phase, nil, "phase should be nil with no game")
    _assert_eq(gate.detained_wait_active, false, "detained_wait_active defaults to false")
  end)

  it("resolve_item_slot_action returns full result when ok", function()
    local state = _item_phase_state({ id = 15, kind = "item_phase_choice", options = { "item_a" } })
    local result = validator.resolve_item_slot_action(_slot_source("item_a"), state, {
      id = "item_slot_2", actor_role_id = 1001,
    }, nil)
    _assert_eq(result.ok, true, "successful resolution returns ok=true")
    assert(result.action ~= nil, "successful resolution returns action table")
  end)
end)
