local support = require("spec.support.gameplay_support")
local fixtures = require("spec.support.gameplay_fixtures")
local _new_game = support.new_game
local _build_loop_state = fixtures.build_loop_state
local runtime_state = require("src.state.runtime")
local gameplay_loop = require("src.turn.loop")
local choice_auto_policy = require("src.turn.policies.choice_auto")

local _log_missing_auto_tests = {
  function()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    local ctx = {
      pending_choice = { id = 123, kind = "test_choice" },
      current_player_auto = true,
    }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == true, "should mark log_once key")
  end,
  function()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    state.auto_runner.waiting_for_interval = true
    local ctx = {
      pending_choice = { id = 123, kind = "test_choice" },
      current_player_auto = true,
    }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == nil, "should not log when waiting for interval")
  end,
  function()
    local state = _build_loop_state()
    runtime_state.ensure_debug_runtime(state)
    local ctx = {
      pending_choice = { id = 123, kind = "test_choice" },
      current_player_auto = false,
    }
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
    assert(state.debug_runtime.log_once["auto_runner_choice_no_action_123"] == nil, "should not log when not auto")
  end,
}

local _choice_auto_policy_tests = {
  function()
    local game = _new_game()
    local choice = { id = 1, options = { { id = "opt1" }, { id = "opt2" } } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil when not auto actor and min_visible not reached")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    local choice = { id = 1, options = { { id = "opt1" } }, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should return action for preconsumed item")
    assert(result.type == "choice_select", "should return choice_select action")
    assert(result.option_id == "opt1", "should select first option")
  end,
  function()
    local game = _new_game()
    local choice = { id = 1, options = { { id = "opt1" } }, allow_cancel = true }
    local ctx = { mode = "tick_timeout" }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should return action for timeout mode")
    assert(result.type == "choice_cancel", "should return choice_cancel when allow_cancel is true")
  end,
}

local _choice_auto_policy_extended_tests = {
  function()
    local game = _new_game()
    local choice = { id = 1, options = { { id = "opt1" }, { id = "opt2" } } }
    -- Test with mode = "wait_choice", not auto, min_visible > 0, elapsed = 0
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 1 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil when min_visible not reached")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test with preconsumed item but no options
    local choice = { id = 1, options = {}, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil for preconsumed item with no options")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test tick_min_visible mode with auto actor
    local choice = { id = 1, options = { { id = "opt1" } } }
    local ctx = { mode = "tick_min_visible", elapsed_seconds = 1, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should return action for tick_min_visible with auto actor")
    assert(result.type == "choice_select", "should return choice_select")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test tick_min_visible mode with elapsed < min_visible
    local choice = { id = 1, options = { { id = "opt1" } } }
    local ctx = { mode = "tick_min_visible", elapsed_seconds = 1, min_visible_seconds = 5 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil when elapsed < min_visible")
  end,
  function()
    local game = _new_game()
    -- Test tick_timeout mode with allow_cancel = false
    local choice = { id = 1, options = { { id = "opt1" } }, allow_cancel = false }
    local ctx = { mode = "tick_timeout" }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should return action for timeout without cancel")
    assert(result.type == "choice_select", "should fallback to choice_select")
  end,
  function()
    local game = _new_game()
    -- Test default mode (unknown mode)
    local choice = { id = 1, options = { { id = "opt1" } } }
    local ctx = { mode = "unknown_mode", allow_first_option_fallback = true }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should return action for unknown mode with fallback")
    assert(result.type == "choice_select", "should return choice_select")
  end,
  function()
    local game = _new_game()
    -- Test default mode without fallback
    local choice = { id = 1, options = { { id = "opt1" } } }
    local ctx = { mode = "unknown_mode", allow_first_option_fallback = false }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil without fallback")
  end,
  function()
    local game = _new_game()
    -- Test with nil choice
    local result = choice_auto_policy.decide(game, {}, nil, {})
    assert(result == nil, "should return nil for nil choice")
  end,
  function()
    local game = _new_game()
    -- Test with choice but no id
    local choice = { options = { { id = "opt1" } } }
    local result = choice_auto_policy.decide(game, {}, choice, {})
    assert(result == nil, "should return nil for choice without id")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test with pending_action in context
    local choice = { id = 1, options = { { id = "opt1" } } }
    local pending = { type = "custom_action" }
    local ctx = { mode = "wait_choice", pending_action = pending }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == pending, "should return pending_action when provided")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test auto_play_port returning nil, fallback to first option
    local choice = { id = 1, options = { { id = "opt2" } }, meta = {} }
    local ctx = { mode = "tick_timeout", allow_first_option_fallback = true }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should fallback to first option")
    assert(result.option_id == "opt2", "should select the actual first option")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test with option id as string directly (not table)
    local choice = { id = 1, options = { "opt_a", "opt_b" }, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should handle string option ids")
    assert(result.option_id == "opt_a", "should select first string option")
  end,
}

-- Additional tests for choice_auto_policy.decide to reach 100% coverage
local _choice_auto_policy_coverage_tests = {
  function()
    -- Test _resolve_choice_owner returns nil when no game
    local choice = { id = 1, owner_role_id = 1 }
    local result = choice_auto_policy.resolve_choice_owner(nil, choice)
    assert(result == nil, "should return nil when no game")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    -- Test _resolve_choice_owner returns player from choice owner_role_id
    local choice = { id = 1, owner_role_id = p1.id }
    local result = choice_auto_policy.resolve_choice_owner(game, choice)
    assert(result == p1, "should return player from choice owner_role_id")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    -- Test _resolve_choice_owner falls back to current_player
    local choice = { id = 1 }
    local result = choice_auto_policy.resolve_choice_owner(game, choice)
    assert(result == p1, "should fallback to current player")
  end,
  function()
    local game = _new_game()
    game.current_player = function() return nil end
    local choice = { id = 1 }
    local result = choice_auto_policy.resolve_choice_owner(game, choice)
    assert(result == nil, "should return nil when no current player")
  end,
  function()
    local game = _new_game()
    -- Test with min_visible=0 (edge case)
    local p1 = game.players[1]
    p1.auto = true
    local choice = { id = 1, options = { { id = "opt1" } }, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should work with min_visible=0")
  end,
  function()
    local game = _new_game()
    -- Test non-auto actor with min_visible <= 0
    local choice = { id = 1, options = { { id = "opt1" } } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    -- Non-auto actor should still return nil because is_auto_actor is false
    assert(result == nil, "non-auto actor should return nil even with min_visible=0")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test preconsumed item with first option having no id field
    local choice = { id = 1, options = { "direct_string_option" }, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should handle string options in preconsumed mode")
    assert(result.option_id == "direct_string_option", "should use string as option_id")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test choice with nil options
    local choice = { id = 1, options = nil, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil when options is nil")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test choice with empty options table
    local choice = { id = 1, options = {}, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result == nil, "should return nil when options is empty")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test negative elapsed seconds normalization
    local choice = { id = 1, options = { { id = "opt1" } }, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = -5, min_visible_seconds = 0 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should handle negative elapsed seconds")
  end,
  function()
    local game = _new_game()
    local p1 = game.players[1]
    p1.auto = true
    -- Test negative min_visible seconds normalization
    local choice = { id = 1, options = { { id = "opt1" } }, meta = { item_preconsumed = true } }
    local ctx = { mode = "wait_choice", elapsed_seconds = 0, min_visible_seconds = -1 }
    local result = choice_auto_policy.decide(game, {}, choice, ctx)
    assert(result ~= nil, "should handle negative min_visible seconds")
  end,
}

describe("auto_runner_policies", function()
  it("_test_log_missing_auto_choice_action_logs_once", _log_missing_auto_tests[1])

  it("_test_log_missing_auto_choice_action_skips_when_waiting", _log_missing_auto_tests[2])

  it("_test_log_missing_auto_choice_action_skips_when_not_auto", _log_missing_auto_tests[3])

  it("_test_choice_auto_policy_wait_choice_not_auto", _choice_auto_policy_tests[1])

  it("_test_choice_auto_policy_preconsumed_item", _choice_auto_policy_tests[2])

  it("_test_choice_auto_policy_timeout_cancel", _choice_auto_policy_tests[3])

  it("_test_choice_auto_policy_min_visible_not_reached", _choice_auto_policy_extended_tests[1])

  it("_test_choice_auto_policy_preconsumed_no_options", _choice_auto_policy_extended_tests[2])

  it("_test_choice_auto_policy_tick_min_visible_auto", _choice_auto_policy_extended_tests[3])

  it("_test_choice_auto_policy_tick_min_visible_not_ready", _choice_auto_policy_extended_tests[4])

  it("_test_choice_auto_policy_timeout_no_cancel", _choice_auto_policy_extended_tests[5])

  it("_test_choice_auto_policy_unknown_mode_fallback", _choice_auto_policy_extended_tests[6])

  it("_test_choice_auto_policy_unknown_mode_no_fallback", _choice_auto_policy_extended_tests[7])

  it("_test_choice_auto_policy_nil_choice", _choice_auto_policy_extended_tests[8])

  it("_test_choice_auto_policy_no_choice_id", _choice_auto_policy_extended_tests[9])

  it("_test_choice_auto_policy_pending_action", _choice_auto_policy_extended_tests[10])

  it("_test_choice_auto_policy_fallback_first_option", _choice_auto_policy_extended_tests[11])

  it("_test_choice_auto_policy_string_option_ids", _choice_auto_policy_extended_tests[12])

  it("_test_choice_auto_policy_resolve_owner_nil_game", _choice_auto_policy_coverage_tests[1])

  it("_test_choice_auto_policy_resolve_owner_from_choice", _choice_auto_policy_coverage_tests[2])

  it("_test_choice_auto_policy_resolve_owner_fallback", _choice_auto_policy_coverage_tests[3])

  it("_test_choice_auto_policy_resolve_owner_no_current", _choice_auto_policy_coverage_tests[4])

  it("_test_choice_auto_policy_min_visible_zero", _choice_auto_policy_coverage_tests[5])

  it("_test_choice_auto_policy_non_auto_min_visible_zero", _choice_auto_policy_coverage_tests[6])

  it("_test_choice_auto_policy_preconsumed_string_option", _choice_auto_policy_coverage_tests[7])

  it("_test_choice_auto_policy_nil_options", _choice_auto_policy_coverage_tests[8])

  it("_test_choice_auto_policy_empty_options", _choice_auto_policy_coverage_tests[9])

  it("_test_choice_auto_policy_negative_elapsed", _choice_auto_policy_coverage_tests[10])

  it("_test_choice_auto_policy_negative_min_visible", _choice_auto_policy_coverage_tests[11])
end)
