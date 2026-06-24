local support = require("spec.support.shared_support")
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

describe("turn_optional_action_completion", function()
  it("allows the current player to complete a cancelable optional action phase", function()
    local choice = {
      id = "optional_1",
      kind = "item_phase_passive",
      allow_cancel = true,
    }
    local result = optional_completion.can_complete_optional_action_phase(_new_game(choice), 1)

    _assert_eq(result.ok, true, "current player should be allowed to complete optional action phase")
    _assert_eq(result.choice, choice, "result should expose the pending optional action choice")
    _assert_eq(result.reason, nil, "allowed result should not carry a rejection reason")
  end)

  it("uses explicit choices and indexed current-player lookup when completing optional phases", function()
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
  end)

  it("returns stable reasons for actors and non optional choices", function()
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
  end)

  it("handles missing actors and caller-owned actor checks distinctly", function()
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
  end)

  it("rejects non-cancelable optional choices and blocked gates with stable reasons", function()
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
  end)

  it("dispatches the completion through one structured choice cancel action", function()
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
    _assert_eq(dispatched.type, "choice_cancel", "completion should cancel the pending optional choice")
    _assert_eq(dispatched.choice_id, "optional_5", "completion should target the pending choice")
    _assert_eq(dispatched.actor_role_id, 1, "completion should carry the current actor")
    _assert_eq(dispatched.input_source, "timer", "completion should preserve the input source")
  end)

  it("falls back to the game dispatcher when no direct completion dispatcher is supplied", function()
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
    _assert_eq(game.dispatched.type, "choice_cancel", "fallback dispatcher should receive choice cancel")
    _assert_eq(game.dispatched.choice_id, "optional_dispatch", "fallback dispatcher should target the choice")
  end)

  it("reports dispatch rejection when no completion dispatcher is available", function()
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
  end)

  it("turn dispatcher owns the completion action and converts it to choice cancel", function()
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
  end)

  it("timeout policy emits the same optional completion intent instead of raw choice cancel", function()
    local choice = {
      id = "optional_7",
      kind = "item_phase_passive",
      allow_cancel = true,
    }
    local result = choice_auto_policy.decide(_new_game(choice), {}, choice, { mode = "tick_timeout" })

    _assert_eq(result.type, "complete_optional_action_phase",
      "optional action timeout should emit optional completion intent")
    _assert_eq(result.choice_id, nil, "optional timeout intent should not expose the pending choice id")
  end)
end)
