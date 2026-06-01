-- Mutation-closure pins for src/turn/loop/init.lua (gameplay_loop assembly).
-- loop_fallback_ports_spec covers the happy-path port install and
-- auto_runner_policies_spec covers new_game + _log_missing_auto_choice_action,
-- leaving the fallback type-guards, the _default_is_auto_player or-chain, the
-- step_auto_runner orchestration (input-block / popup-wait / dispatch / actor
-- fill), and the _initialize_ports construction alive. This spec drives the
-- exported surface + _M_test directly, with a fake gameplay_loop_ports table.
-- Routed by architect (agent_context/rules-mutation-bootstrap-debt.md):
-- L25 _default_is_auto_player, L43/50 fallback type-guards, L106 popup-owner
-- cluster, L159/163/164 _initialize_ports.
local support = require("spec.support.shared_support")
local fixtures = require("spec.support.gameplay_fixtures")
local config_reset = require("spec.support.config_reset")
local gameplay_loop = require("src.turn.loop.init")
local auto_play_port = require("src.rules.ports.auto_play")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local timing = require("src.config.gameplay.timing")
local runtime_state = require("src.state.runtime")
local tick_flow = require("src.turn.loop.tick_flow")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _ensure = gameplay_loop._M_test.ensure_fallback_ports

describe("gameplay_loop fallback-port guards closure", function()
  before_each(function() config_reset.reset_all() end)

  it("preserves an already-present port function", function()
    local custom = function() return "kept" end
    local game = { auto_play_port = { is_auto_player = custom } }
    _ensure(game)
    _assert_eq(game.auto_play_port.is_auto_player, custom,
      "an existing function field is not overwritten by the default")
  end)

  it("replaces a non-function port field with the default", function()
    local game = { auto_play_port = { is_auto_player = "not a function" } }
    _ensure(game)
    _assert_eq(type(game.auto_play_port.is_auto_player), "function",
      "a non-function field is replaced by the default function")
    assert(game.auto_play_port.is_auto_player ~= "not a function", "the string field is overwritten")
  end)

  it("replaces a non-table auto_play_port with a fresh defaulted table", function()
    local game = { auto_play_port = "nope" }
    _ensure(game)
    _assert_eq(type(game.auto_play_port), "table", "a non-table auto_play_port becomes a table")
    _assert_eq(type(game.auto_play_port.choose_action), "function", "the fresh table is defaulted")
  end)

  it("replaces a non-table bankruptcy_port with a fresh defaulted table", function()
    local game = { auto_play_port = {}, bankruptcy_port = 42 }
    _ensure(game)
    _assert_eq(type(game.bankruptcy_port), "table", "a non-table bankruptcy_port becomes a table")
    _assert_eq(type(game.bankruptcy_port.eliminate), "function", "the bankruptcy table is defaulted")
  end)

  -- _default_is_auto_player or-chain (L25) ---------------------------------

  local function _is_auto(player)
    local game = { auto_play_port = {} }
    _ensure(game)
    return game.auto_play_port.is_auto_player(game, player)
  end

  it("the default treats player.auto == true as auto", function()
    _assert_eq(_is_auto({ auto = true }), true, ".auto true marks an auto player")
  end)

  it("the default treats player.is_ai == true as auto", function()
    _assert_eq(_is_auto({ is_ai = true }), true, ".is_ai true marks an auto player")
  end)

  it("the default treats player.ai == true as auto", function()
    _assert_eq(_is_auto({ ai = true }), true, ".ai true marks an auto player")
  end)

  it("the default treats a player with no auto flags as human", function()
    _assert_eq(_is_auto({ auto = false }), false, "no auto flag means not auto")
  end)

  it("the default treats a nil player as not auto", function()
    _assert_eq(_is_auto(nil), false, "a nil player is never auto")
  end)
end)

describe("gameplay_loop.step_auto_runner closure", function()
  before_each(function() config_reset.reset_all() end)

  local function _runner_state(next_action)
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local ports = fixtures.build_test_ports()
    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    local called = { next_action = false }
    state.auto_runner.next_action = function(_, _) called.next_action = true; return next_action end
    return game, state, ports, called
  end

  it("short-circuits to nil while input is blocked, before consulting the runner", function()
    local game, state, _, called = _runner_state({ type = "x" })
    state.ui.input_blocked = true
    local result = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    _assert_eq(result, nil, "blocked input yields no auto action")
    _assert_eq(called.next_action, false, "the auto runner is never consulted while input is blocked")
  end)

  it("short-circuits to nil while an auto-owned popup is still within its visible window", function()
    local game, state, _, called = _runner_state({ type = "x" })
    state.ui.input_blocked = false
    state.ui.popup_active = true
    state.ui.popup_owner_index = 1
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 5.0 }, -- min visible > 0
      { target = auto_play_port, key = "is_auto_player", value = function() return true end },
    }, function()
      local result = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
      _assert_eq(result, nil, "an auto popup inside its visible window suppresses the auto action")
      _assert_eq(called.next_action, false, "the runner is not consulted while the popup waits")
    end)
  end)

  it("dispatches the runner's action and back-fills the ui_button actor", function()
    local dispatched
    local game, state = _runner_state({ type = "ui_button" }) -- no actor_role_id
    state.ui.input_blocked = false
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 }, -- skip the popup-wait gate
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action) dispatched = action; return true end },
    }, function()
      local action = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
      assert(dispatched ~= nil, "a runner action is dispatched")
      _assert_eq(dispatched.type, "ui_button", "the runner action flows through dispatch")
      assert(dispatched.actor_role_id ~= nil, "a ui_button action without an actor is back-filled with the current player")
      _assert_eq(action, dispatched, "step_auto_runner returns the dispatched action")
    end)
  end)

  it("returns nil and dispatches nothing when the runner yields no action", function()
    local dispatched = false
    local game, state = _runner_state(nil)
    state.ui.input_blocked = false
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 },
      { target = turn_dispatch, key = "dispatch_action", value = function() dispatched = true; return true end },
    }, function()
      local action = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
      _assert_eq(action, nil, "no runner action means no return value")
      _assert_eq(dispatched, false, "nothing is dispatched when the runner is idle")
    end)
  end)

  -- _is_auto_popup_waiting / _is_auto_popup_owner guard branches. The positive
  -- "waiting" case is pinned above (runner not consulted); these pin every way
  -- the gate falls through so the runner IS consulted despite delay > 0.

  -- Drive step_auto_runner with the popup-wait window open (delay > 0) but one
  -- gate condition failing, and assert the runner still runs.
  local function _assert_runner_consulted_with(state_mutator, is_auto)
    local game, state, _, called = _runner_state({ type = "x" })
    state.ui.input_blocked = false
    state.ui.popup_active = true
    state.ui.popup_owner_index = 1
    state_mutator(state)
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
      { target = auto_play_port, key = "is_auto_player", value = function() return is_auto end },
      { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    return called.next_action
  end

  it("does not wait when the active popup is owned by a human", function()
    -- _is_auto_popup_owner returns false -> not waiting -> runner consulted.
    _assert_eq(_assert_runner_consulted_with(function() end, false), true,
      "a human-owned popup must not suppress the auto runner")
  end)

  it("does not wait when no popup is active", function()
    -- is_popup_active false short-circuits _is_auto_popup_waiting.
    _assert_eq(_assert_runner_consulted_with(function(s) s.ui.popup_active = false end, true), true,
      "without an active popup the runner is consulted even inside the visible window")
  end)
  -- "no owner index" fall-through is pinned in the actor-fill + popup-gate
  -- describe below ("consults the runner when the popup owner is unknown").

  it("treats an unset auto-decision delay as a 0 visible window (no wait)", function()
    -- kills _is_auto_popup_waiting's `auto_decision_delay_seconds or 0` -> `or 1`:
    -- a nil delay must mean 0 (gate short-circuits, runner consulted), not 1
    -- (which would hold an auto popup at elapsed 0 and suppress the runner).
    local game, state, _, called = _runner_state({ type = "x" })
    state.ui.input_blocked = false
    state.ui.popup_active = true
    state.ui.popup_owner_index = 1
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = nil },
      { target = auto_play_port, key = "is_auto_player", value = function() return true end },
      { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    _assert_eq(called.next_action, true,
      "a nil delay yields a 0 window (<=0) so the runner is consulted, not held")
  end)

  it("holds the runner while a sub-second visible window has not elapsed", function()
    -- kills _is_auto_popup_waiting's `<= 0` -> `<= 1`: a 0.5s window must still be
    -- treated as a positive gate (the popup waits), not collapsed by `<= 1`.
    local game, state, _, called = _runner_state({ type = "x" })
    state.ui.input_blocked = false
    state.ui.popup_active = true
    state.ui.popup_owner_index = 1
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0.5 },
      { target = auto_play_port, key = "is_auto_player", value = function() return true end },
      { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    _assert_eq(called.next_action, false,
      "a 0.5s window is positive (not <= 1 collapsed), so the auto popup still waits")
  end)

  it("wires on_close_choice to the modal port for the fresh modal ref (the ~= cache guard)", function()
    -- kills _dispatch_action_with_close_choice's `_cached_modal_ports_ref ~= modal_ports`
    -- -> `==`: with `==` the close-choice closure is not (re)built for this ref,
    -- so invoking on_close_choice does not reach this modal's close_choice_modal.
    local dispatched, closed
    local game, state, ports = _runner_state({ type = "ui_button", actor_role_id = 1 })
    state.ui.input_blocked = false
    ports.modal = { close_choice_modal = function() closed = true end }
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 },
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, _, opts)
          dispatched = opts
          return true
        end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    assert(dispatched ~= nil, "the runner action dispatches with a close-choice opts table")
    assert(type(dispatched.on_close_choice) == "function", "a fresh modal ref wires on_close_choice")
    dispatched.on_close_choice({})
    _assert_eq(closed, true, "invoking on_close_choice routes to this modal's close_choice_modal")
  end)
end)

describe("gameplay_loop bankruptcy_feedback_port arg-shuffle closure", function()
  before_each(function() config_reset.reset_all() end)

  -- _initialize_ports wires on_tiles_cleared to tolerate both a 3-arg and a
  -- 4-arg call shape; the `arg4 ~= nil` branch picks which positional slots
  -- carry the game context and the owned tile ids.
  local function _captured_tile_ids(invoke)
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    gameplay_loop.set_game(state, game)
    local captured
    game.board_visual_feedback_port.sync_many = function(_, payload)
      captured = payload.tile_ids
    end
    invoke(game.bankruptcy_feedback_port.on_tiles_cleared, game)
    return captured
  end

  it("reads tile ids from the 4th argument in the 4-arg shape", function()
    local ids = _captured_tile_ids(function(on_cleared)
      on_cleared("self", "game_ctx", "ignored", { 7, 8 })
    end)
    assert(ids and ids[1] == 7 and ids[2] == 8,
      "the 4-arg shape forwards arg4 as the owned tile ids")
  end)

  it("reads tile ids from the 3rd argument in the 3-arg shape", function()
    local ids = _captured_tile_ids(function(on_cleared)
      on_cleared("game_ctx", "unused", { 3 })
    end)
    -- arg4 is nil here, so game_ctx = arg1 and owned_tile_ids = arg3.
    assert(ids and ids[1] == 3, "the 3-arg shape forwards arg3 as the owned tile ids")
  end)
end)

describe("gameplay_loop.set_game initialize-ports closure", function()
  before_each(function() config_reset.reset_all() end)

  it("constructs the full runtime port set on the game", function()
    local game = support.new_game()
    local state = fixtures.build_loop_state()

    gameplay_loop.set_game(state, game)

    _assert_eq(type(game.board_scene_port), "table", "set_game builds the board scene port")
    _assert_eq(type(game.popup_port), "table", "set_game builds the popup port")
    _assert_eq(type(game.tip_output_port), "table", "set_game builds the tip output port")
    _assert_eq(type(game.event_feed_port), "table", "set_game builds the event feed port")
    _assert_eq(type(game.anim_gate_port), "table", "set_game builds the anim gate port")
    _assert_eq(type(game.intent_output_port), "table", "set_game builds the intent output port")
    _assert_eq(type(game.bankruptcy_feedback_port), "table", "set_game builds the bankruptcy feedback port")
    _assert_eq(type(game.tile_owner_notifier), "table", "set_game wires the tile owner notifier")
    _assert_eq(type(game.auto_play_port.is_auto_player), "function", "set_game ensures the fallback auto-play port")
  end)

  it("clears stale runtime state and releases the role-control lock", function()
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    state.player_units = { "stale" }
    state.countdown_last = 5
    state.countdown_active_last = true

    gameplay_loop.set_game(state, game)

    _assert_eq(state.player_units, nil, "set_game clears stale player units")
    _assert_eq(state.player_units_missing, false, "set_game clears the missing-units flag")
    _assert_eq(state.countdown_last, nil, "set_game clears the countdown cache")
    _assert_eq(state.countdown_active_last, nil, "set_game clears the countdown-active cache")
    local turn_runtime = runtime_state.ensure_turn_runtime(state)
    _assert_eq(turn_runtime.role_control_lock_active, false, "set_game releases the role-control lock")
    _assert_eq(turn_runtime.role_control_lock_suppress, 0, "set_game zeroes the lock suppression")
  end)

  it("preserves a pre-existing game.state table rather than replacing it", function()
    -- kills _initialize_ports' `game.state = game.state or {}` -> `and {}`:
    -- with `and`, a present game.state would be overwritten by a fresh table.
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local sentinel = { sentinel = true }
    game.state = sentinel

    gameplay_loop.set_game(state, game)

    _assert_eq(game.state, sentinel, "an existing game.state is kept (the `or` keeps the current value)")
  end)
end)

describe("gameplay_loop.step_auto_runner actor-fill + popup-gate closure", function()
  before_each(function() config_reset.reset_all() end)

  local function _runner_state(next_action)
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local ports = fixtures.build_test_ports()
    state._resolved_gameplay_loop_ports = ports
    state.gameplay_loop_ports = ports
    state.ui.input_blocked = false
    state.auto_runner.next_action = function() return next_action end
    return game, state
  end

  it("does not back-fill an actor on a non-ui_button action", function()
    local dispatched
    local game, state = _runner_state({ type = "roll_dice" })
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 },
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action) dispatched = action; return true end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    _assert_eq(dispatched.actor_role_id, nil, "a non-ui_button action is left without an actor back-fill")
  end)

  it("does not overwrite an explicit actor on a ui_button action", function()
    local dispatched
    local game, state = _runner_state({ type = "ui_button", actor_role_id = 777 })
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 0 },
      { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action) dispatched = action; return true end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    _assert_eq(dispatched.actor_role_id, 777, "an explicit ui_button actor_role_id is preserved")
  end)

  it("consults the runner when the popup owner is unknown", function()
    local consulted = false
    local game, state = _runner_state(nil)
    state.ui.popup_active = true
    state.ui.popup_owner_index = nil -- get_popup_owner_index -> nil
    state.auto_runner.next_action = function() consulted = true; return nil end
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    _assert_eq(consulted, true, "an unknown popup owner is not auto-waiting, so the runner is consulted")
  end)

  it("consults the runner once the popup visible window has elapsed", function()
    local consulted = false
    local game, state = _runner_state(nil)
    state.ui.popup_active = true
    state.ui.popup_owner_index = 1
    state.auto_runner.next_action = function() consulted = true; return nil end
    _with_patches({
      { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
      { target = auto_play_port, key = "is_auto_player", value = function() return true end },
      { target = runtime_state, key = "get_modal_elapsed", value = function() return 99.0 end },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    end)
    _assert_eq(consulted, true, "elapsed >= the min-visible window no longer suppresses the runner")
  end)
end)

describe("gameplay_loop.tick closure", function()
  before_each(function() config_reset.reset_all() end)

  it("is a no-op when no game is present", function()
    local ticked = false
    _with_patches({
      { target = tick_flow, key = "tick", value = function() ticked = true end },
    }, function()
      gameplay_loop.tick(nil, fixtures.build_loop_state(), 0.1)
    end)
    _assert_eq(ticked, false, "a nil game short-circuits before reaching tick_flow")
  end)

  it("ensures the runtime intent port and delegates to tick_flow with the auto-runner dep", function()
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    game.intent_output_port = nil
    local captured
    _with_patches({
      { target = tick_flow, key = "tick", value = function(_, _, _, ports, deps) captured = { ports = ports, deps = deps } end },
    }, function()
      gameplay_loop.tick(game, state, 0.1)
    end)
    assert(captured ~= nil, "tick delegates to tick_flow.tick")
    _assert_eq(type(game.intent_output_port), "table", "tick ensures the runtime intent output port")
    assert(captured.deps.step_auto_runner ~= nil, "tick wires the step_auto_runner dependency")
    _assert_eq(type(captured.ports), "table", "tick resolves and forwards the gameplay loop ports")
  end)

  it("preserves an intent_output_port that is already a table", function()
    -- The other direction of the L64 `~= "table"` guard: an existing port table
    -- must not be rebuilt.
    local game = support.new_game()
    local state = fixtures.build_loop_state()
    local sentinel = { sentinel = true }
    game.intent_output_port = sentinel
    _with_patches({
      { target = tick_flow, key = "tick", value = function() end },
    }, function()
      gameplay_loop.tick(game, state, 0.1)
    end)
    _assert_eq(game.intent_output_port, sentinel,
      "an existing intent_output_port table is not rebuilt")
  end)
end)
