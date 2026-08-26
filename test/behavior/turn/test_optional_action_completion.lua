local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local optional_completion = require("src.turn.optional_action_completion")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local turn_dispatch = require("src.turn.actions.action_dispatcher")

local function _new_game(choice)
  return {
    players = {
      { id = 1 },
      { id = 2 },
    },
    auto_play_port = {
      is_auto_player = function()
        return false
      end,
      auto_action_for_choice = function()
        return nil
      end,
    },
    turn = {
      current_player_index = 1,
      pending_choice = choice,
    },
    current_player = function(self)
      return self.players[self.turn.current_player_index]
    end,
  }
end

TestOptionalActionCompletion = {}

function TestOptionalActionCompletion:test_allows_the_current_player_to_complete_a_cancelable_optional_action_phase()
  local choice = {
    id = "optional_1",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local result = optional_completion.can_complete_optional_action_phase(_new_game(choice), 1)

  _assert_eq(result.ok, true, "current player should be allowed to complete optional action phase")
  _assert_eq(result.choice, choice, "result should expose the pending optional action choice")
  _assert_eq(result.reason, nil, "allowed result should not carry a rejection reason")
end

function TestOptionalActionCompletion:test_uses_explicit_choices_and_indexed_current_player_lookup_when_completing_optional_phases()
  local pending_choice = {
    id = "required_choice",
    kind = "market_buy",
    allow_cancel = true,
  }
  local explicit_choice = {
    id = "optional_override",
    kind = "landing_optional_effect",
    allow_cancel = true,
  }
  local game = _new_game(pending_choice)
  game.current_player = nil

  local result = optional_completion.can_complete_optional_action_phase(game, 1, nil, {
    choice = explicit_choice,
  })

  _assert_eq(result.ok, true, "explicit optional choice should override pending required choice")
  _assert_eq(result.choice, explicit_choice, "result should use the explicit optional choice")

  local wrong_actor = optional_completion.can_complete_optional_action_phase(game, 2, nil, {
    choice = explicit_choice,
  })
  _assert_eq(wrong_actor.ok, false, "indexed current-player lookup should reject other actors")
  _assert_eq(wrong_actor.reason, "not_current_player", "indexed current-player rejection reason")
end

function TestOptionalActionCompletion:test_prefers_an_explicit_current_player_method_over_indexed_fallback()
  local choice = {
    id = "optional_method_actor",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local game = _new_game(choice)
  game.turn.current_player_index = 1
  function game:current_player()
    return self.players[2]
  end

  local indexed_actor = optional_completion.can_complete_optional_action_phase(game, 1)
  _assert_eq(indexed_actor.ok, false, "current_player method should override stale index")
  _assert_eq(indexed_actor.reason, "not_current_player", "method current-player rejection reason")

  local method_actor = optional_completion.can_complete_optional_action_phase(game, 2)
  _assert_eq(method_actor.ok, true, "method current player should be allowed")
end

function TestOptionalActionCompletion:test_does_not_reject_actors_when_the_current_player_cannot_be_resolved()
  local choice = {
    id = "optional_missing_current",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local game = {
    turn = {
      current_player_index = 1,
      pending_choice = choice,
    },
  }

  local result = optional_completion.can_complete_optional_action_phase(game, 1)
  _assert_eq(result.ok, true, "missing player list should leave actor ownership to caller")
  _assert_eq(result.choice, choice, "missing player list should preserve the optional choice")
end

function TestOptionalActionCompletion:test_returns_stable_reasons_for_actors_and_non_optional_choices()
  local actor_result = optional_completion.can_complete_optional_action_phase(_new_game({
    id = "optional_2",
    kind = "landing_optional_effect",
    allow_cancel = true,
  }), 2)
  _assert_eq(actor_result.ok, false, "non-current actor should be rejected")
  _assert_eq(actor_result.reason, "not_current_player", "actor rejection reason")

  local missing_result = optional_completion.can_complete_optional_action_phase(_new_game(nil), 1)
  _assert_eq(missing_result.ok, false, "missing optional choice should be rejected")
  _assert_eq(missing_result.reason, "no_optional_action", "missing optional reason")

  local required_choice_result = optional_completion.can_complete_optional_action_phase(_new_game({
    id = "required_choice",
    kind = "market_buy",
    allow_cancel = true,
  }), 1)
  _assert_eq(required_choice_result.ok, false, "required choices should not use optional completion")
  _assert_eq(required_choice_result.reason, "no_optional_action", "required choice reason")
  _assert_eq(required_choice_result.choice, nil, "required choices should not leak through no-optional results")
end

function TestOptionalActionCompletion:test_handles_missing_actors_and_caller_owned_actor_checks_distinctly()
  local choice = {
    id = "optional_actor",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local missing_actor = optional_completion.can_complete_optional_action_phase(_new_game(choice), nil)
  _assert_eq(missing_actor.ok, false, "missing actor should be rejected by default")
  _assert_eq(missing_actor.reason, "missing_actor", "missing actor reason")
  _assert_eq(missing_actor.choice, choice, "missing actor result should keep the optional choice")

  local unchecked_actor = optional_completion.can_complete_optional_action_phase(_new_game(choice), nil, nil, {
    require_actor = false,
  })
  _assert_eq(unchecked_actor.ok, true, "callers can take ownership of actor validation")
  _assert_eq(unchecked_actor.choice, choice, "unchecked actor result should keep the optional choice")
end

function TestOptionalActionCompletion:test_rejects_non_cancelable_optional_choices_and_blocked_gates_with_stable_reasons()
  local non_cancelable = optional_completion.can_complete_optional_action_phase(_new_game({
    id = "optional_3",
    kind = "item_phase_passive",
    allow_cancel = false,
  }), 1)
  _assert_eq(non_cancelable.ok, false, "non-cancelable optional choice should be rejected")
  _assert_eq(non_cancelable.reason, "not_cancelable_optional_action", "non-cancelable reason")

  local blocked = optional_completion.can_complete_optional_action_phase(_new_game({
    id = "optional_4",
    kind = "item_phase_passive",
    allow_cancel = true,
  }), 1, nil, {
    gate_state = {
      input_blocked = true,
    },
  })
  _assert_eq(blocked.ok, false, "blocked input should reject optional completion")
  _assert_eq(blocked.reason, "blocked", "blocked reason")
end

function TestOptionalActionCompletion:test_dispatches_the_completion_through_one_structured_choice_cancel_action()
  local choice = {
    id = "optional_5",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local dispatched = nil
  local result = optional_completion.complete_optional_action_phase(_new_game(choice), 1, nil, {
    dispatch_choice_action = function(action)
      dispatched = action
      return { status = "applied" }
    end,
    input_source = "timer",
  })

  _assert_eq(result.ok, true, "completion should report success")
  _assert_eq(result.status, "applied", "completion should expose dispatch status")
  _assert_eq(result.reason, nil, "successful completion should not report a rejection reason")
  _assert_eq(dispatched.type, "choice_cancel", "completion should cancel the pending optional choice")
  _assert_eq(dispatched.choice_id, "optional_5", "completion should target the pending choice")
  _assert_eq(dispatched.actor_role_id, 1, "completion should carry the current actor")
  _assert_eq(dispatched.input_source, "timer", "completion should preserve the input source")
end

function TestOptionalActionCompletion:test_falls_back_to_the_game_dispatcher_when_no_direct_completion_dispatcher_is_supplied()
  local choice = {
    id = "optional_dispatch",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local game = _new_game(choice)
  function game:dispatch_action(action)
    self.dispatched = action
  end

  local result = optional_completion.complete_optional_action_phase(game, 1)

  _assert_eq(result.ok, true, "game dispatcher fallback should apply completion")
  _assert_eq(result.status, "applied", "game dispatcher fallback should report applied")
  _assert_eq(result.reason, nil, "game dispatcher fallback should not report a rejection reason")
  _assert_eq(game.dispatched.type, "choice_cancel", "fallback dispatcher should receive choice cancel")
  _assert_eq(game.dispatched.choice_id, "optional_dispatch", "fallback dispatcher should target the choice")
end

function TestOptionalActionCompletion:test_reports_dispatch_rejection_when_no_completion_dispatcher_is_available()
  local choice = {
    id = "optional_rejected",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local result = optional_completion.complete_optional_action_phase(_new_game(choice), 1)

  _assert_eq(result.ok, false, "missing dispatcher should reject completion")
  _assert_eq(result.status, "rejected", "missing dispatcher status")
  _assert_eq(result.reason, "dispatch_rejected", "missing dispatcher reason")
  _assert_eq(result.action.choice_id, "optional_rejected", "rejected completion should expose attempted action")
end

function TestOptionalActionCompletion:test_complete_returns_the_rejection_when_no_optional_action_is_open()
  local result = optional_completion.complete_optional_action_phase(_new_game(nil), 1)

  _assert_eq(result.ok, false, "completion without an optional action must reject")
  _assert_eq(result.reason, "no_optional_action", "completion preserves the eligibility rejection")
end

function TestOptionalActionCompletion:test_turn_dispatcher_owns_the_completion_action_and_converts_it_to_choice_cancel()
  local choice = {
    id = "optional_6",
    kind = "landing_optional_effect",
    allow_cancel = true,
  }
  local game = _new_game(choice)
  function game:dispatch_action(action)
    self.dispatched = action
    self.turn.pending_choice = nil
  end

  local result = turn_dispatch.dispatch_action(game, {}, {
    type = "complete_optional_action_phase",
    actor_role_id = 1,
  })

  _assert_eq(result.status, "applied", "turn dispatcher should apply optional completion")
  _assert_eq(game.dispatched.type, "choice_cancel", "turn dispatcher should dispatch choice cancel internally")
  _assert_eq(game.dispatched.choice_id, "optional_6", "turn dispatcher should target the pending optional choice")
  _assert_eq(game.turn.pending_choice, nil, "turn dispatcher should clear the completed choice")
end

function TestOptionalActionCompletion:test_timeout_policy_emits_the_same_optional_completion_intent_instead_of_raw_choice_cancel()
  local choice = {
    id = "optional_7",
    kind = "item_phase_passive",
    allow_cancel = true,
  }
  local result = choice_auto_policy.decide(_new_game(choice), {}, choice, { mode = "tick_timeout" })

  _assert_eq(result.type, "complete_optional_action_phase",
    "optional action timeout should emit optional completion intent")
  _assert_eq(result.choice_id, nil, "optional timeout intent should not expose the pending choice id")
end


return TestOptionalActionCompletion
