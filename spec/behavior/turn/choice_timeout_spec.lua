local support = require("spec.support.shared_support")
local fixtures = require("spec.support.gameplay_fixtures")
local _new_game = support.new_game
local _build_loop_state = fixtures.build_loop_state
local _build_test_ports = fixtures.build_test_ports
local tick_choice_timeout = require("src.turn.waits.choice_timeout")
local tick_timeout = require("src.turn.waits.timeout")
local runtime_state = require("src.state.runtime")

local _resolve_choice_owner_tests = {
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p1.id, "should resolve owner from choice")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    g.turn.current_player_index = 1
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p1.id, "should fallback to current player")
  end,
  function()
    local g = _new_game()
    g.turn.current_player_index = nil
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == nil, "should return nil when no player found")
  end,
}

local _resolve_choice_owner_id_extended_tests = {
  function()
    local g = _new_game()
    local p2 = g.players[2]
    g.turn.current_player_index = 2
    local choice = { id = 1, owner_role_id = 999 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p2.id, "should fallback to current player when owner not found")
  end,
  function()
    local g = _new_game()
    g.turn.current_player_index = 5
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == nil, "should return nil when current player index out of range")
  end,
  function()
    local g = _new_game()
    g.find_player_by_id = function() return nil end
    local choice = { id = 1, owner_role_id = 123 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result ~= nil, "should fallback when find_player_by_id returns nil")
  end,
  function()
    local g = _new_game()
    g.turn = nil
    local choice = { id = 1, owner_role_id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    local p1 = _new_game().players[1]
    assert(result == p1.id or result == nil, "should handle nil turn gracefully")
  end,
  function()
    local g = _new_game()
    g.players = nil
    local choice = { id = 1 }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == nil, "should return nil when no players array")
  end,
  function()
    local g = _new_game()
    g.find_player_by_id = nil
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local result = tick_choice_timeout._resolve_choice_owner_id(g, choice)
    assert(result == p1.id, "should fallback to current player when find_player_by_id missing")
  end,
}

local _resolve_choice_ui_state_t2_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "market_buy" }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.market_buy, "market_buy should use scope_timeouts.market_buy")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "normal_choice" }
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.choice, "normal choice should use scope_timeouts.choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.choice, "nil pending_choice should use scope_timeouts.choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    runtime_state.set_pending_choice(state, { id = 2, kind = "market_buy" })
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state)
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.market_buy, "should get pending_choice from runtime state")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local timeout = tick_timeout.resolve_choice_timeout_seconds(game, state, { id = 3, kind = "market_buy" })
    local timing = require("src.config.gameplay.timing")
    assert(timeout == timing.scope_timeouts.market_buy, "should use passed choice parameter")
  end,
}

local _resolve_choice_ui_state_final_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local on_pending_calls = 0

    local ports = _build_test_ports({
      ui_sync = {
        is_choice_active = function() return true end,
        on_pending_choice = function() on_pending_calls = on_pending_calls + 1 end,
      }
    })

    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    local original_choice = { id = 1, kind = "test", route_key = "test_route" }
    game.turn.pending_choice = original_choice

    local original_get_pending_choice = runtime_state.get_pending_choice
    local original_get_pending_choice_elapsed = runtime_state.get_pending_choice_elapsed
    runtime_state.get_pending_choice = function() return game.turn.pending_choice end
    runtime_state.get_pending_choice_elapsed = function() return 0 end

    tick_timeout.step_default_choice(game, state, 0.016)

    runtime_state.get_pending_choice = original_get_pending_choice
    runtime_state.get_pending_choice_elapsed = original_get_pending_choice_elapsed

    assert(game.turn.pending_choice == original_choice, "zero elapsed must not clear pending choice")
    assert(on_pending_calls == 0, "zero elapsed must not dispatch timeout")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local on_pending_calls = 0

    local ports = _build_test_ports({
      ui_sync = {
        is_choice_active = function() return true end,
        on_pending_choice = function() on_pending_calls = on_pending_calls + 1 end,
      }
    })

    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    local original_choice = { id = 1, kind = "test" }
    game.turn.pending_choice = original_choice

    local original_get_pending_choice = runtime_state.get_pending_choice
    local original_get_pending_choice_elapsed = runtime_state.get_pending_choice_elapsed
    runtime_state.get_pending_choice = function() return game.turn.pending_choice end
    runtime_state.get_pending_choice_elapsed = function() return 0 end

    tick_timeout.step_default_choice(game, state, 0.016)

    runtime_state.get_pending_choice = original_get_pending_choice
    runtime_state.get_pending_choice_elapsed = original_get_pending_choice_elapsed

    assert(game.turn.pending_choice == original_choice, "missing route_key must not clear pending choice")
    assert(on_pending_calls == 0, "missing route_key must not dispatch timeout")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local on_pending_calls = 0

    local ports = _build_test_ports({
      ui_sync = {
        is_choice_active = function() return false end,
        on_pending_choice = function() on_pending_calls = on_pending_calls + 1 end,
      }
    })

    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports

    local original_get_pending_choice = runtime_state.get_pending_choice
    runtime_state.get_pending_choice = function() return nil end

    tick_timeout.step_default_choice(game, state, 0.016)

    runtime_state.get_pending_choice = original_get_pending_choice

    assert(on_pending_calls == 0, "nil choice must not dispatch timeout")
  end,
}

describe("choices_timeout", function()
  it("_test_tick_choice_timeout_resolve_choice_owner_id_from_choice", _resolve_choice_owner_tests[1])

  it("_test_tick_choice_timeout_resolve_choice_owner_id_fallback", _resolve_choice_owner_tests[2])

  it("_test_tick_choice_timeout_resolve_choice_owner_id_not_found", _resolve_choice_owner_tests[3])

  it("_test_resolve_choice_owner_id_fallback_current", _resolve_choice_owner_id_extended_tests[1])

  it("_test_resolve_choice_owner_id_out_of_range", _resolve_choice_owner_id_extended_tests[2])

  it("_test_resolve_choice_owner_find_nil", _resolve_choice_owner_id_extended_tests[3])

  it("_test_resolve_choice_owner_nil_turn", _resolve_choice_owner_id_extended_tests[4])

  it("_test_resolve_choice_owner_no_players", _resolve_choice_owner_id_extended_tests[5])

  it("_test_resolve_choice_owner_missing_find_player", _resolve_choice_owner_id_extended_tests[6])

  it("_test_resolve_choice_timeout_market_buy", _resolve_choice_ui_state_t2_tests[1])

  it("_test_resolve_choice_timeout_normal_choice", _resolve_choice_ui_state_t2_tests[2])

  it("_test_resolve_choice_timeout_nil_pending", _resolve_choice_ui_state_t2_tests[3])

  it("_test_resolve_choice_timeout_runtime_pending", _resolve_choice_ui_state_t2_tests[4])

  it("_test_resolve_choice_timeout_param_choice", _resolve_choice_ui_state_t2_tests[5])

  it("_test_resolve_choice_ui_state_custom_callback", _resolve_choice_ui_state_final_tests[1])

  it("_test_resolve_choice_ui_state_fallback", _resolve_choice_ui_state_final_tests[2])

  it("_test_resolve_choice_ui_state_nil_choice", _resolve_choice_ui_state_final_tests[3])
end)

-- Mutation-closure pins for tick_choice_timeout.step and its private helpers.
-- Drives step directly with a controllable output-port stub (injected via
-- state.gameplay_loop_ports.output) plus custom opts so the min-visible /
-- timeout boundaries, the config fallbacks, the force-skip branch, and the
-- ui-active warning gate are observable one tick at a time.
local _timing = require("src.config.gameplay.timing")
local _constants = require("src.config.content.constants")
local _choice_auto_policy = require("src.turn.policies.choice_auto")
local _config_reset = require("spec.support.config_reset")
local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local function _make_output(init)
  local o = {
    pending_choice = init.pending_choice,
    pending_choice_id = init.pending_choice_id,
    pending_choice_elapsed = init.pending_choice_elapsed or 0,
  }
  o.ports = {
    get_pending_choice = function() return o.pending_choice end,
    sync_pending_choice = function(_, choice)
      o.pending_choice = choice
      o.pending_choice_id = choice and choice.id or nil
      o.pending_choice_elapsed = 0
    end,
    clear_pending_choice = function()
      o.pending_choice = nil
      o.pending_choice_id = nil
      o.pending_choice_elapsed = 0
    end,
    get_pending_choice_id = function() return o.pending_choice_id end,
    set_pending_choice_id = function(_, id) o.pending_choice_id = id end,
    get_pending_choice_elapsed = function() return o.pending_choice_elapsed end,
    set_pending_choice_elapsed = function(_, value) o.pending_choice_elapsed = value end,
  }
  return o
end

local function _run_step(cfg)
  local choice = cfg.choice or { id = 1, kind = "test", route_key = "r" }
  local game = { turn = { pending_choice = choice } }
  local output = _make_output({
    pending_choice = choice,
    pending_choice_id = choice.id,
    pending_choice_elapsed = cfg.elapsed or 0,
  })
  if cfg.unstored_pending then
    output.ports.get_pending_choice = function() return nil end
    output.ports.sync_pending_choice = function() end
  end
  local state = { gameplay_loop_ports = { output = output.ports } }
  local rec = { built = {}, dispatched = {} }
  local opts = {
    on_pending_choice = function() end,
    is_choice_active = cfg.is_choice_active or function() return true end,
    resolve_choice_ui_state = cfg.resolve_choice_ui_state,
    build_action = function(_, _, _, payload)
      rec.built[#rec.built + 1] = {
        mode = payload.mode,
        elapsed_seconds = payload.elapsed_seconds,
        timeout_seconds = payload.timeout_seconds,
        min_visible_seconds = payload.min_visible_seconds,
      }
      if cfg.build_action then
        return cfg.build_action(payload)
      end
      return { type = "auto", actor_role_id = 1 }
    end,
    dispatch_action_with_close_choice = function(_, _, action)
      rec.dispatched[#rec.dispatched + 1] = action
    end,
    get_timeout_seconds = cfg.get_timeout_seconds,
    get_min_visible_seconds = cfg.get_min_visible_seconds,
  }
  tick_choice_timeout.step(game, state, cfg.dt or 0, opts)
  return rec, state, output
end

local function _fixed_timeout(seconds)
  return function() return seconds end
end

local function _fixed_min_visible(seconds)
  return function() return seconds end
end

describe("choices_timeout step boundaries", function()
  before_each(function() _config_reset.reset_all() end)

  it("skips all work when the timeout is not positive", function()
    -- kills L84 <= -> <: a zero timeout must reset-and-return before any build.
    local rec = _run_step({ get_timeout_seconds = _fixed_timeout(0), elapsed = 5 })
    _assert_eq(#rec.built, 0, "a zero timeout short-circuits before building an action")
  end)

  it("fires the timeout exactly when elapsed equals the timeout", function()
    -- kills L64 < -> <=: elapsed == timeout must resolve (not return early).
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(10),
      get_min_visible_seconds = _fixed_min_visible(100),
      elapsed = 10,
    })
    _assert_eq(#rec.built, 1, "elapsed == timeout builds the timeout action")
    _assert_eq(rec.built[1].mode, "tick_timeout", "the timeout build carries the tick_timeout mode")
  end)

  it("routes a force-skip action through deadline resolution, not dispatch", function()
    -- kills L71 "choice_force_skip"->nil: a force-skip action must take the
    -- deadline-resolution branch, never opts.dispatch_action_with_close_choice.
    _with_patches({
      { target = _choice_auto_policy, key = "decide", value = function() return nil end },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(10),
        get_min_visible_seconds = _fixed_min_visible(100),
        elapsed = 10,
        build_action = function() return { type = "choice_force_skip" } end,
      })
      _assert_eq(#rec.dispatched, 0, "a force-skip action is not dispatched via the close-choice path")
    end)
  end)

  it("resolves the choice via deadlines when the timeout build returns nil", function()
    -- kills L5 require(deadlines)->nil and L71 and->or: a nil timeout action must
    -- reach deadlines.resolve_choice (which clears the pending choice); a nil
    -- deadlines module or an `or` guard indexing nil.type would error instead.
    _with_patches({
      { target = _choice_auto_policy, key = "decide", value = function() return nil end },
    }, function()
      local rec, _, output = _run_step({
        get_timeout_seconds = _fixed_timeout(10),
        get_min_visible_seconds = _fixed_min_visible(100),
        elapsed = 10,
        build_action = function() return nil end,
      })
      _assert_eq(#rec.dispatched, 0, "a nil timeout action does not dispatch")
      assert(output.pending_choice == nil, "deadline resolution force-skips and clears the pending choice")
    end)
  end)
end)

describe("choices_timeout step min-visible gate", function()
  before_each(function() _config_reset.reset_all() end)

  it("dispatches the min-visible tick and stamps its mode", function()
    -- kills L13 "tick_min_visible"->nil and L56 dispatch_choice_tick_action->nil.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(100),
      get_min_visible_seconds = _fixed_min_visible(2),
      elapsed = 5,
    })
    _assert_eq(#rec.built, 1, "the min-visible gate builds one action")
    _assert_eq(rec.built[1].mode, "tick_min_visible", "the min-visible build carries the tick_min_visible mode")
    _assert_eq(#rec.dispatched, 1, "the min-visible action is dispatched")
  end)

  it("returns after the min-visible dispatch instead of also resolving the timeout", function()
    -- kills L103 _maybe_dispatch_min_visible->nil: when both gates would fire the
    -- min-visible dispatch must win and short-circuit the timeout resolution.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(10),
      get_min_visible_seconds = _fixed_min_visible(2),
      elapsed = 20,
    })
    _assert_eq(#rec.built, 1, "only one action builds when the min-visible gate wins")
    _assert_eq(rec.built[1].mode, "tick_min_visible", "the min-visible gate wins over the timeout")
  end)

  it("does not dispatch min-visible when the window is exactly zero", function()
    -- kills L53 > -> >=: min_visible == 0 must not open the gate.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(100),
      get_min_visible_seconds = _fixed_min_visible(0),
      elapsed = 5,
    })
    _assert_eq(#rec.built, 0, "a zero min-visible window never dispatches")
  end)

  it("dispatches min-visible for a sub-second window", function()
    -- kills L53 0 -> 1: a 0.5s window must still count as > 0.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(100),
      get_min_visible_seconds = _fixed_min_visible(0.5),
      elapsed = 5,
    })
    _assert_eq(#rec.built, 1, "a 0.5s min-visible window opens the gate")
    _assert_eq(rec.built[1].mode, "tick_min_visible", "the sub-second window dispatches a min-visible tick")
  end)

  it("does not dispatch min-visible before the window elapses", function()
    -- kills L53 and->or: both the positive-window and elapsed-reached conditions
    -- must hold.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(100),
      get_min_visible_seconds = _fixed_min_visible(5),
      elapsed = 2,
    })
    _assert_eq(#rec.built, 0, "an unreached min-visible window does not dispatch")
  end)

  it("dispatches min-visible exactly when elapsed reaches the window", function()
    -- kills L53 >= -> >: elapsed == min_visible must open the gate.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(100),
      get_min_visible_seconds = _fixed_min_visible(5),
      elapsed = 5,
    })
    _assert_eq(#rec.built, 1, "elapsed == min_visible opens the gate")
    _assert_eq(rec.built[1].mode, "tick_min_visible", "the boundary dispatch is a min-visible tick")
  end)
end)

describe("choices_timeout step min-visible resolution", function()
  before_each(function() _config_reset.reset_all() end)

  it("uses the opts override for the min-visible window", function()
    -- kills L43 type/"function"->nil, L44 override call->nil, L45 is_numeric->nil:
    -- the override (8) must reach the timeout payload rather than the config
    -- default (patched to 50).
    _with_patches({
      { target = _timing, key = "auto_decision_delay_seconds", value = 50 },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(5),
        get_min_visible_seconds = _fixed_min_visible(8),
        elapsed = 5,
      })
      _assert_eq(rec.built[1].mode, "tick_timeout", "an 8s window is not reached, so the timeout resolves")
      _assert_eq(rec.built[1].min_visible_seconds, 8, "the override min-visible reaches the timeout payload")
    end)
  end)

  it("rejects a negative override and keeps the config default", function()
    -- kills L45 and->or: a negative override must fail the (numeric AND >= 0)
    -- guard and fall back to the default 50.
    _with_patches({
      { target = _timing, key = "auto_decision_delay_seconds", value = 50 },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(5),
        get_min_visible_seconds = _fixed_min_visible(-3),
        elapsed = 5,
      })
      _assert_eq(rec.built[1].min_visible_seconds, 50, "a negative override is rejected for the default")
    end)
  end)

  it("accepts a zero override at the >= 0 boundary", function()
    -- kills L45 >= -> >: an override of exactly 0 must be accepted.
    _with_patches({
      { target = _timing, key = "auto_decision_delay_seconds", value = 50 },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(5),
        get_min_visible_seconds = _fixed_min_visible(0),
        elapsed = 5,
      })
      _assert_eq(rec.built[1].min_visible_seconds, 0, "a zero override is accepted (>= 0), not rejected")
    end)
  end)

  it("accepts a sub-one override at the 0 literal", function()
    -- kills L45 0 -> 1: an override of 0.5 must pass the >= 0 guard.
    _with_patches({
      { target = _timing, key = "auto_decision_delay_seconds", value = 50 },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(0.4),
        get_min_visible_seconds = _fixed_min_visible(0.5),
        elapsed = 0.45,
      })
      _assert_eq(rec.built[1].min_visible_seconds, 0.5, "a 0.5 override is accepted (>= 0, not >= 1)")
    end)
  end)

  it("uses the configured auto-decision delay when no override is given", function()
    -- kills L42 or->and: with no override the default must be the config value
    -- (50), not the `and 0` collapse.
    _with_patches({
      { target = _timing, key = "auto_decision_delay_seconds", value = 50 },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(5),
        elapsed = 5,
      })
      _assert_eq(rec.built[1].min_visible_seconds, 50, "the default min-visible mirrors the config delay")
    end)
  end)

  it("defaults the min-visible window to 0 when the config delay is unset", function()
    -- kills L42 0 -> 1: an unset auto-decision delay must yield a 0 window (which
    -- takes the timeout path), not a 1s window (which would open the gate).
    _with_patches({
      { target = _timing, key = "auto_decision_delay_seconds", value = nil },
    }, function()
      local rec = _run_step({
        get_timeout_seconds = _fixed_timeout(5),
        elapsed = 5,
      })
      _assert_eq(rec.built[1].mode, "tick_timeout", "a 0 default window takes the timeout path")
      _assert_eq(rec.built[1].min_visible_seconds, 0, "an unset delay yields a 0 min-visible window")
    end)
  end)

  it("treats an absent constants base as a zero timeout", function()
    -- kills L31 0 -> 1: with no constants base and no override the timeout is 0
    -- (or 0, not or 1), so the step short-circuits before building.
    _with_patches({
      { target = _constants, key = "action_timeout_seconds", value = nil },
    }, function()
      local rec = _run_step({ elapsed = 5 })
      _assert_eq(#rec.built, 0, "an absent constants base yields a 0 timeout and no build")
    end)
  end)
end)

describe("choices_timeout step missing-ui warning gate", function()
  before_each(function() _config_reset.reset_all() end)

  it("does not warn when the ui reports the choice active", function()
    -- kills L89 == -> ~= and true -> false: is_choice_active() == true must mark
    -- the ui active so the missing-ui warning stays silent.
    local logged = {}
    _with_patches({
      { target = runtime_state, key = "log_once", value = function() logged[#logged + 1] = true end },
    }, function()
      _run_step({
        get_timeout_seconds = _fixed_timeout(100),
        get_min_visible_seconds = _fixed_min_visible(100),
        elapsed = 1,
        is_choice_active = function() return true end,
      })
    end)
    _assert_eq(#logged, 0, "an active ui suppresses the missing-ui warning")
  end)

  it("resets and returns when a pending choice never resolves an active choice", function()
    -- kills L94 or->and: with pending present but no stored active_choice the
    -- (not active OR not active_choice) guard must reset-and-return; an `and`
    -- mutant would fall through and index a nil active_choice.
    local rec = _run_step({
      get_timeout_seconds = _fixed_timeout(100),
      get_min_visible_seconds = _fixed_min_visible(100),
      elapsed = 1,
      unstored_pending = true,
    })
    _assert_eq(#rec.built, 0, "an unresolved active choice resets and returns before any build")
  end)
end)
