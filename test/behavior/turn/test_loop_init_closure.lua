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
-- 原生 LuaUnit 改写：10 个带同款 before_each 的 describe 合并为一个 Test* 类
-- （46 例，before_each → setUp），describe 级 helper 提到文件级；describe 5
-- 与 describe 2 同名的 _runner_state 因签名不同改名 _runner_state_actor_fill；
-- assert.has_error → luax.has_error。
local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local fixtures = require("test.support.gameplay_fixtures")
local config_reset = require("test.support.config_reset")
local gameplay_loop = require("src.turn.loop.init")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local timing = require("src.config.gameplay.timing")
local runtime_state = require("src.state.runtime")
local logger = require("src.foundation.log")
local control = require("src.player.control")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local _ensure = gameplay_loop._M_test.ensure_fallback_ports

-- 默认自动行动端口转发统一玩家控制查询 --------------------------------

local function _is_computer_controlled(player)
  local game = { auto_play_port = {} }
  _ensure(game)
  return game.auto_play_port.is_computer_controlled(game, player)
end

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
  if is_auto then
    control.toggle_manual_delegation(game.players[1])
  end
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  return called.next_action
end

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

local function _runner_state_actor_fill(next_action)
  local game = support.new_game()
  local state = fixtures.build_loop_state()
  local ports = fixtures.build_test_ports()
  state._resolved_gameplay_loop_ports = ports
  state.gameplay_loop_ports = ports
  state.ui.input_blocked = false
  state.auto_runner.next_action = function() return next_action end
  return game, state
end

TestLoopInitClosure = {}

function TestLoopInitClosure:setUp()
  config_reset.reset_all()
end

function TestLoopInitClosure:test_preserves_an_already_present_port_function()
  local custom = function() return "kept" end
  local game = { auto_play_port = { is_computer_controlled = custom } }
  _ensure(game)
  _assert_eq(game.auto_play_port.is_computer_controlled, custom,
    "an existing function field is not overwritten by the default")
end

function TestLoopInitClosure:test_replaces_a_non_function_port_field_with_the_default()
  local game = { auto_play_port = { is_computer_controlled = "not a function" } }
  _ensure(game)
  _assert_eq(type(game.auto_play_port.is_computer_controlled), "function",
    "a non-function field is replaced by the default function")
  lu.assertEvalToTrue(game.auto_play_port.is_computer_controlled ~= "not a function", "the string field is overwritten")
end

function TestLoopInitClosure:test_replaces_a_non_table_auto_play_port_with_a_fresh_defaulted_table()
  local game = { auto_play_port = "nope" }
  _ensure(game)
  _assert_eq(type(game.auto_play_port), "table", "a non-table auto_play_port becomes a table")
  _assert_eq(type(game.auto_play_port.choose_action), "function", "the fresh table is defaulted")
end

function TestLoopInitClosure:test_replaces_a_non_table_bankruptcy_port_with_a_fresh_defaulted_table()
  local game = { auto_play_port = {}, bankruptcy_port = 42 }
  _ensure(game)
  _assert_eq(type(game.bankruptcy_port), "table", "a non-table bankruptcy_port becomes a table")
  _assert_eq(type(game.bankruptcy_port.eliminate), "function", "the bankruptcy table is defaulted")
end

function TestLoopInitClosure:test_preserves_an_already_table_bankruptcy_port_and_its_functions()
  -- kills _ensure_fallback_ports' `type(...) ~= "table"` string-to-nil on the
  -- bankruptcy guard: an existing table must be kept, not rebuilt.
  local custom = function() return "kept" end
  local game = { auto_play_port = {}, bankruptcy_port = { eliminate = custom } }
  local ref = game.bankruptcy_port
  _ensure(game)
  _assert_eq(game.bankruptcy_port, ref, "an existing bankruptcy_port table is not rebuilt")
  _assert_eq(game.bankruptcy_port.eliminate, custom, "an existing eliminate function is preserved")
end

function TestLoopInitClosure:test_the_default_treats_a_manually_delegated_player_as_computer_controlled()
  local player = { id = 1 }
  control.initialize(player)
  control.toggle_manual_delegation(player)
  _assert_eq(_is_computer_controlled(player), true, "manual delegation marks computer control")
end

function TestLoopInitClosure:test_the_default_treats_a_replacement_computer_as_computer_controlled()
  local player = { id = 1, is_ai = true }
  control.initialize(player)
  _assert_eq(_is_computer_controlled(player), true, "is_ai true marks computer control")
end

function TestLoopInitClosure:test_the_default_treats_a_direct_player_as_not_computer_controlled()
  local player = { id = 1 }
  control.initialize(player)
  _assert_eq(_is_computer_controlled(player), false, "direct control means a human wait")
end

function TestLoopInitClosure:test_the_default_treats_a_nil_player_as_not_computer_controlled()
  _assert_eq(_is_computer_controlled(nil), false, "a nil player is never computer controlled")
end

function TestLoopInitClosure:test_short_circuits_to_nil_while_input_is_blocked_before_consulting_the_runner()
  local game, state, _, called = _runner_state({ type = "x" })
  state.ui.input_blocked = true
  local result = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  _assert_eq(result, nil, "blocked input yields no auto action")
  _assert_eq(called.next_action, false, "the auto runner is never consulted while input is blocked")
end

function TestLoopInitClosure:test_short_circuits_to_nil_while_an_auto_owned_popup_is_still_within_its_visible_window()
  local game, state, _, called = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  state.ui.popup_active = true
  state.ui.popup_owner_index = 1
  control.toggle_manual_delegation(game.players[1])
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 5.0 }, -- min visible > 0
  }, function()
    local result = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    _assert_eq(result, nil, "an auto popup inside its visible window suppresses the auto action")
    _assert_eq(called.next_action, false, "the runner is not consulted while the popup waits")
  end)
end

function TestLoopInitClosure:test_dispatches_the_runners_action_and_back_fills_the_ui_button_actor()
  local dispatched
  local game, state = _runner_state({ type = "ui_button" }) -- no actor_role_id
  state.ui.input_blocked = false
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 0 }, -- skip the popup-wait gate
    { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action) dispatched = action; return true end },
  }, function()
    local action = gameplay_loop.step_auto_runner(game, state, 0.1, nil)
    lu.assertEvalToTrue(dispatched ~= nil, "a runner action is dispatched")
    _assert_eq(dispatched.type, "ui_button", "the runner action flows through dispatch")
    lu.assertEvalToTrue(dispatched.actor_role_id ~= nil, "a ui_button action without an actor is back-filled with the current player")
    _assert_eq(action, dispatched, "step_auto_runner returns the dispatched action")
  end)
end

function TestLoopInitClosure:test_returns_nil_and_dispatches_nothing_when_the_runner_yields_no_action()
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
end

function TestLoopInitClosure:test_does_not_wait_when_the_active_popup_is_owned_by_a_human()
  -- _is_auto_popup_owner returns false -> not waiting -> runner consulted.
  _assert_eq(_assert_runner_consulted_with(function() end, false), true,
    "a human-owned popup must not suppress the auto runner")
end

function TestLoopInitClosure:test_does_not_wait_when_no_popup_is_active()
  -- is_popup_active false short-circuits _is_auto_popup_waiting.
  _assert_eq(_assert_runner_consulted_with(function(s) s.ui.popup_active = false end, true), true,
    "without an active popup the runner is consulted even inside the visible window")
end

function TestLoopInitClosure:test_treats_an_unset_auto_decision_delay_as_a_0_visible_window_no_wait()
  -- kills _is_auto_popup_waiting's `auto_decision_delay_seconds or 0` -> `or 1`:
  -- a nil delay must mean 0 (gate short-circuits, runner consulted), not 1
  -- (which would hold an auto popup at elapsed 0 and suppress the runner).
  local game, state, _, called = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  state.ui.popup_active = true
  state.ui.popup_owner_index = 1
  control.toggle_manual_delegation(game.players[1])
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = nil },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(called.next_action, true,
    "a nil delay yields a 0 window (<=0) so the runner is consulted, not held")
end

function TestLoopInitClosure:test_an_explicit_zero_delay_short_circuits_before_ever_consulting_popup_state()
  -- kills _is_auto_popup_waiting's `min_popup_visible <= 0` -> `< 0`: with the
  -- delay exactly 0 the gate must short-circuit; `< 0` would fall through and
  -- consult is_popup_active (which here raises on contact).
  local game, state, ports, called = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  ports.ui_sync.is_popup_active = function()
    error("popup state consulted for a zero visible window")
  end
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 0 },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(called.next_action, true,
    "a zero visible window never waits on popup state")
end

function TestLoopInitClosure:test_treats_a_ui_sync_port_without_get_popup_owner_index_as_no_auto_owner()
  -- kills _is_auto_popup_owner's guard `and` -> `or` mutants plus the guard's
  -- `return false` -> true: a ui_sync group lacking get_popup_owner_index must
  -- mean "not an auto popup owner" (runner consulted) — `or` mutants fall
  -- through and call the missing function, `return true` forces an owner and
  -- suppresses the runner.
  local game, state, ports, called = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  ports.ui_sync.is_popup_active = function() return true end
  ports.ui_sync.get_popup_owner_index = nil -- ui_sync group without the owner lookup
  -- prime the resolved-ports cache so _resolve_ports returns this exact
  -- (deliberately incomplete) ports table instead of a merged re-resolve.
  -- 注意:只设 source 不设 resolved 缓存会命中 _resolve_ports 的 merge 路径,
  -- resolve 会用 base 默认端口把 get_popup_owner_index 补回来,测试便测不到
  -- 「缺失」语义;两者必须同设才能绕过 merge。
  state._resolved_gameplay_loop_ports = ports
  state._resolved_gameplay_loop_ports_source = ports
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(called.next_action, true,
    "without get_popup_owner_index the popup owner is unknown, so the runner is consulted")
end

function TestLoopInitClosure:test_treats_a_game_without_players_as_no_auto_owner()
  -- kills _is_auto_popup_owner's `not idx or not game.players` `or` -> `and`:
  -- idx resolves but game.players is missing -> not an owner (runner
  -- consulted); `and` falls through and indexes the nil players list.
  local game, state, ports, called = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  game.players = nil
  ports.ui_sync.is_popup_active = function() return true end
  ports.ui_sync.get_popup_owner_index = function() return 1 end
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(called.next_action, true,
    "without a players list the popup owner is not auto, so the runner is consulted")
end

function TestLoopInitClosure:test_reuses_the_cached_resolved_ports_while_the_override_is_unchanged()
  -- kills _resolve_ports' `_resolved_gameplay_loop_ports_source == override`
  -- `==` -> `~=`: a cache hit must return the same table, not re-resolve.
  local game, state, ports = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  state._resolved_gameplay_loop_ports_source = ports -- prime the cache for this override
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 0 },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(state._resolved_gameplay_loop_ports, ports,
    "an unchanged override hits the resolved-ports cache")
end

function TestLoopInitClosure:test_holds_the_runner_while_a_sub_second_visible_window_has_not_elapsed()
  -- kills _is_auto_popup_waiting's `<= 0` -> `<= 1`: a 0.5s window must still be
  -- treated as a positive gate (the popup waits), not collapsed by `<= 1`.
  local game, state, _, called = _runner_state({ type = "x" })
  state.ui.input_blocked = false
  state.ui.popup_active = true
  state.ui.popup_owner_index = 1
  control.toggle_manual_delegation(game.players[1])
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 0.5 },
    { target = turn_dispatch, key = "dispatch_action", value = function() return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(called.next_action, false,
    "a 0.5s window is positive (not <= 1 collapsed), so the auto popup still waits")
end

function TestLoopInitClosure:test_wires_on_close_choice_to_the_modal_port_for_the_fresh_modal_ref_the_cache_guard()
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
  lu.assertEvalToTrue(dispatched ~= nil, "the runner action dispatches with a close-choice opts table")
  lu.assertEvalToTrue(type(dispatched.on_close_choice) == "function", "a fresh modal ref wires on_close_choice")
  dispatched.on_close_choice({})
  _assert_eq(closed, true, "invoking on_close_choice routes to this modal's close_choice_modal")
end

function TestLoopInitClosure:test_reads_tile_ids_from_the_4th_argument_in_the_4_arg_shape()
  local ids = _captured_tile_ids(function(on_cleared)
    on_cleared("self", "game_ctx", "ignored", { 7, 8 })
  end)
  lu.assertEvalToTrue(ids and ids[1] == 7 and ids[2] == 8,
    "the 4-arg shape forwards arg4 as the owned tile ids")
end

function TestLoopInitClosure:test_reads_tile_ids_from_the_3rd_argument_in_the_3_arg_shape()
  local ids = _captured_tile_ids(function(on_cleared)
    on_cleared("game_ctx", "unused", { 3 })
  end)
  -- arg4 is nil here, so game_ctx = arg1 and owned_tile_ids = arg3.
  lu.assertEvalToTrue(ids and ids[1] == 3, "the 3-arg shape forwards arg3 as the owned tile ids")
end

function TestLoopInitClosure:test_constructs_the_full_runtime_port_set_on_the_game()
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
  _assert_eq(type(game.auto_play_port.is_computer_controlled), "function", "set_game ensures the fallback auto-play port")
end

function TestLoopInitClosure:test_clears_stale_runtime_state_and_releases_the_role_control_lock()
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
end

function TestLoopInitClosure:test_preserves_a_pre_existing_game_state_table_rather_than_replacing_it()
  -- kills _initialize_ports' `game.state = game.state or {}` -> `and {}`:
  -- with `and`, a present game.state would be overwritten by a fresh table.
  local game = support.new_game()
  local state = fixtures.build_loop_state()
  local sentinel = { sentinel = true }
  game.state = sentinel

  gameplay_loop.set_game(state, game)

  _assert_eq(game.state, sentinel, "an existing game.state is kept (the `or` keeps the current value)")
end

function TestLoopInitClosure:test_does_not_back_fill_an_actor_on_a_non_ui_button_action()
  local dispatched
  local game, state = _runner_state_actor_fill({ type = "roll_dice" })
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 0 },
    { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action) dispatched = action; return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(dispatched.actor_role_id, nil, "a non-ui_button action is left without an actor back-fill")
end

function TestLoopInitClosure:test_does_not_overwrite_an_explicit_actor_on_a_ui_button_action()
  local dispatched
  local game, state = _runner_state_actor_fill({ type = "ui_button", actor_role_id = 777 })
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 0 },
    { target = turn_dispatch, key = "dispatch_action", value = function(_, _, action) dispatched = action; return true end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(dispatched.actor_role_id, 777, "an explicit ui_button actor_role_id is preserved")
end

function TestLoopInitClosure:test_consults_the_runner_when_the_popup_owner_is_unknown()
  local consulted = false
  local game, state = _runner_state_actor_fill(nil)
  state.ui.popup_active = true
  state.ui.popup_owner_index = nil -- get_popup_owner_index -> nil
  state.auto_runner.next_action = function() consulted = true; return nil end
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(consulted, true, "an unknown popup owner is not auto-waiting, so the runner is consulted")
end

function TestLoopInitClosure:test_consults_the_runner_once_the_popup_visible_window_has_elapsed()
  local consulted = false
  local game, state = _runner_state_actor_fill(nil)
  state.ui.popup_active = true
  state.ui.popup_owner_index = 1
  state.auto_runner.next_action = function() consulted = true; return nil end
  control.toggle_manual_delegation(game.players[1])
  _with_patches({
    { target = timing, key = "auto_decision_delay_seconds", value = 5.0 },
    { target = runtime_state, key = "get_modal_elapsed", value = function() return 99.0 end },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0.1, nil)
  end)
  _assert_eq(consulted, true, "elapsed >= the min-visible window no longer suppresses the runner")
end

function TestLoopInitClosure:test_is_a_no_op_when_no_game_is_present()
  local state = fixtures.build_loop_state()
  gameplay_loop.tick(nil, state, 0.1)
  _assert_eq(state._resolved_gameplay_loop_ports, nil, "a nil game short-circuits before resolving ports")
end

function TestLoopInitClosure:test_nil_state_still_installs_runtime_game_ports_before_short_circuiting()
  local game = support.new_game()
  game.intent_output_port = nil
  gameplay_loop.tick(game, nil, 0.1)
  _assert_eq(type(game.intent_output_port), "table", "tick installs the intent port before a nil-state short circuit")
end

function TestLoopInitClosure:test_ensures_runtime_ports_and_caches_resolved_loop_ports()
  local game = support.new_game()
  local state = fixtures.build_loop_state()
  game.intent_output_port = nil
  gameplay_loop.tick(game, state, 0.1)
  _assert_eq(type(game.intent_output_port), "table", "tick ensures the runtime intent output port")
  _assert_eq(type(state._resolved_gameplay_loop_ports), "table", "tick caches the resolved gameplay loop ports")
  _assert_eq(type(state._resolved_gameplay_loop_ports.ui_sync), "table", "resolved ports include ui_sync")
end

function TestLoopInitClosure:test_preserves_an_intent_output_port_that_is_already_a_table()
  -- The other direction of the L64 `~= "table"` guard: an existing port table
  -- must not be rebuilt.
  local game = support.new_game()
  local state = fixtures.build_loop_state()
  local sentinel = { sentinel = true }
  game.intent_output_port = sentinel
  gameplay_loop.tick(game, state, 0.1)
  _assert_eq(game.intent_output_port, sentinel,
    "an existing intent_output_port table is not rebuilt")
end

function TestLoopInitClosure:test_set_game_rejects_a_nil_game_with_its_guard_message()
  -- kills set_game's `"missing game"` -> nil: the assert message is the
  -- contract callers see.
  luax.has_error(function()
    gameplay_loop.set_game(fixtures.build_loop_state(), nil)
  end, "missing game")
end

function TestLoopInitClosure:test_set_game_rejects_a_game_without_pending_choice()
  -- kills _configure_pending_choice's `"missing game.pending_choice"` -> nil.
  luax.has_error(function()
    gameplay_loop.set_game(fixtures.build_loop_state(), { turn = {} })
  end, "missing game.pending_choice")
end

function TestLoopInitClosure:test_step_auto_runner_rejects_a_nil_game()
  luax.has_error(function()
    gameplay_loop.step_auto_runner(nil, fixtures.build_loop_state(), 0.1, nil)
  end, "missing game")
end

function TestLoopInitClosure:test_step_auto_runner_rejects_a_state_without_an_auto_runner()
  local state = fixtures.build_loop_state()
  state.auto_runner = nil
  luax.has_error(function()
    gameplay_loop.step_auto_runner(support.new_game(), state, 0.1, nil)
  end, "missing auto_runner")
end

function TestLoopInitClosure:test_new_game_rejects_a_state_without_a_game_factory()
  luax.has_error(function()
    gameplay_loop.new_game({})
  end, "game_factory not set")
end

function TestLoopInitClosure:test_new_game_rejects_a_state_without_an_auto_runner()
  -- #293: L278 assert 消息变异(消息串翻 nil)——new_game 缺 auto_runner 时
  -- 必须报出标识消息,消息变异才被钉住(step_auto_runner 的同款消息已有
  -- 测试,new_game 这条此前只有 game_factory 先行断言被覆盖)。
  local state = {
    game_factory = function() return { players = {} } end,
  }
  luax.has_error(function()
    gameplay_loop.new_game(state)
  end, "missing auto_runner")
end

function TestLoopInitClosure:test_new_game_rejects_an_auto_runner_without_reset_timer()
  local state = {
    game_factory = function() return { players = {} } end,
    auto_runner = {},
  }
  luax.has_error(function()
    gameplay_loop.new_game(state)
  end, "missing auto_runner.ResetTimer")
end

function TestLoopInitClosure:test_forwards_the_games_pending_choice_to_the_output_port()
  -- kills _configure_pending_choice's `game:pending_choice()` -> nil: the
  -- synced pending choice must be exactly what the game reports.
  local game = support.new_game()
  local pending = { id = 42, kind = "test_choice", options = {} }
  game.pending_choice = function() return pending end
  local synced
  local ports = fixtures.build_test_ports({
    build_model = function() return {} end,
  })
  ports.output = {
    sync_pending_choice = function(_, value) synced = value end,
  }
  local state = fixtures.build_loop_state()
  state.gameplay_loop_ports = ports

  gameplay_loop.set_game(state, game)

  _assert_eq(synced, pending, "set_game syncs the game's pending choice to the output port")
end

function TestLoopInitClosure:test_reports_the_games_turn_count_and_stays_nil_safe_without_a_turn()
  -- kills _configure_environment's `game.turn and game.turn.turn_count`
  -- `and` -> `or`: with a turn present the provider must return the count
  -- (`or` yields the turn table); with turn nil it must return nil (`or`
  -- indexes nil and raises).
  local game = support.new_game()
  game.turn.turn_count = 7
  local provider
  _with_patches({
    { target = logger, key = "set_info_turn_provider", value = function(fn) provider = fn end },
  }, function()
    gameplay_loop.set_game(fixtures.build_loop_state(), game)
  end)
  lu.assertEvalToTrue(provider ~= nil, "set_game installs the info turn provider")
  _assert_eq(provider(), 7, "the provider reports turn.turn_count")
  game.turn = nil
  _assert_eq(provider(), nil, "the provider stays nil-safe without a turn")
end

function TestLoopInitClosure:test_logs_the_missing_auto_choice_action_with_level_prefix_and_message()
  -- kills _log_missing_auto_choice_action's "warn" / "[Eggy]" / message
  -- string-to-nil mutants: the log_once call must carry all three literals.
  local captured
  local state = fixtures.build_loop_state()
  local ctx = {
    pending_choice = { id = 7, kind = "test_choice" },
    current_player_computer_controlled = true,
  }
  _with_patches({
    { target = runtime_state, key = "log_once", value = function(_, ...) captured = { ... } end },
  }, function()
    gameplay_loop._log_missing_auto_choice_action(state, ctx)
  end)
  lu.assertEvalToTrue(captured ~= nil, "a missing auto action is logged once")
  _assert_eq(captured[1], "warn", "the log level is warn")
  _assert_eq(captured[2], "auto_runner_choice_no_action_7", "the log_once key carries the choice id")
  _assert_eq(captured[3], "[Eggy]", "the log prefix is [Eggy]")
  _assert_eq(captured[4], "auto runner produced no action for runtime pending choice",
    "the log message describes the missing action")
end

function TestLoopInitClosure:test_new_game_logs_the_startup_banner_with_the_player_count()
  -- kills new_game's "启动蛋仔大富翁，玩家数:" -> nil: the banner literal must
  -- reach the module logger as the first argument.
  local logged
  local fake_game = { players = { {}, {} } }
  local state = {
    game_factory = function() return fake_game end,
    auto_runner = { reset_timer = function() end },
  }
  _with_patches({
    { target = logger, key = "info", value = function(...) logged = { ... } end },
  }, function()
    gameplay_loop.new_game(state)
  end)
  lu.assertEvalToTrue(logged ~= nil, "new_game logs through the module logger")
  _assert_eq(logged[1], "启动蛋仔大富翁，玩家数:", "the startup banner literal")
  _assert_eq(logged[2], 2, "the player count follows the banner")
end


return TestLoopInitClosure
