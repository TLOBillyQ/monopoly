local support = require("support.gameplay_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local gameplay_loop = require("src.game.flow.turn.loop")
local tick_choice_timeout = require("src.game.flow.turn.tick_choice_timeout")
local turn_timer_policy = require("src.game.flow.turn.timer_policy")
local dispatch_validator = require("src.game.flow.turn.dispatch_validator")
local runtime_state = require("src.core.state_access.runtime_state")
local roll = require("src.game.flow.turn.roll")

local function _build_test_ports(overrides)
  overrides = overrides or {}
  return {
    modal = {
      close_choice_modal = overrides.close_choice_modal or function() end,
      open_choice_modal = overrides.open_choice_modal or function() end,
      close_popup = overrides.close_popup or function() end,
    },
    anim = {
      play_move_anim = overrides.play_move_anim or function() return 0 end,
      play_action_anim = overrides.play_action_anim or function() return 0 end,
      reset_status_3d = overrides.reset_status_3d or function() end,
      sync_status_3d = overrides.sync_status_3d or function() end,
    },
    ui_sync = {
      apply_input_lock = overrides.apply_input_lock or function() end,
      step_choice_timeout = overrides.step_choice_timeout or function() end,
      step_modal_timeout = overrides.step_modal_timeout or function() end,
      update_countdown = overrides.update_countdown or function() end,
      build_model = overrides.build_model or function() return nil end,
      refresh_from_dirty = overrides.refresh_from_dirty or function() return false end,
      follow_camera = overrides.follow_camera or function() return false end,
      get_ui_state = overrides.get_ui_state or function(state) return state and state.ui or nil end,
      is_input_blocked = overrides.is_input_blocked or function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = overrides.is_popup_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = overrides.is_choice_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = overrides.is_market_active or function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = overrides.get_popup_owner_index or function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_owner_index or nil
      end,
      resolve_ui_gate = overrides.resolve_ui_gate or function(state)
        local ui = state and state.ui or nil
        local popup = ui and ui.popup_payload or nil
        return {
          input_blocked = ui and ui.input_blocked == true or false,
          choice_active = ui and ui.choice_active == true or false,
          market_active = ui and ui.market_active == true or false,
          popup_active = ui and ui.popup_active == true or false,
          popup_seq = ui and ui.popup_seq or nil,
          popup_auto_close_seconds = popup and popup.auto_close_seconds or nil,
          popup_owner_index = ui and ui.popup_owner_index or nil,
        }
      end,
      set_input_blocked = overrides.set_input_blocked or function(state, blocked)
        local ui = state and state.ui or nil
        if not ui then
          return false
        end
        if ui.input_blocked == blocked then
          return false
        end
        ui.input_blocked = blocked
        return true
      end,
    },
    debug = {
      log_status = overrides.log_status or function() end,
      sync_debug_log = overrides.sync_debug_log or function() end,
      resolve_debug_enabled = overrides.resolve_debug_enabled or function() return false end,
    },
    clock = {
      wall_now_seconds = overrides.wall_now_seconds or function()
        return 0
      end,
      wall_diff_seconds = overrides.wall_diff_seconds or function(timestamp_1, timestamp_2)
        return (timestamp_1 or 0) - (timestamp_2 or 0)
      end,
      cpu_now_seconds = overrides.cpu_now_seconds or function()
        return 0
      end,
      cpu_diff_seconds = overrides.cpu_diff_seconds or function(timestamp_1, timestamp_2)
        return (timestamp_1 or 0) - (timestamp_2 or 0)
      end,
    },
    state = {
      apply_role_control_lock = overrides.apply_role_control_lock or function() end,
      install_event_handlers = overrides.install_event_handlers or function() end,
      on_bankruptcy_tiles_cleared = overrides.on_bankruptcy_tiles_cleared or function() end,
    },
  }
end

local function _build_loop_state()
  local auto_runner = require("src.game.flow.turn.auto_runner")
  local ui_port = _build_ui_port()
  local state = {
    gameplay_loop_ports = _build_test_ports({
      refresh_from_dirty = function() return false end,
      build_model = function() return nil end,
      sync_status_3d = function() end,
      reset_status_3d = function() end,
      update_countdown = function() end,
      log_status = function() end,
      sync_debug_log = function() end,
    }),
    ui = ui_port.ui,
    ui_refs = ui_port.ui_refs,
    ui_model = nil,
    set_label = ui_port.set_label,
    set_visible = ui_port.set_visible,
    set_touch_enabled = ui_port.set_touch_enabled,
    query_node = ui_port.query_node,
    auto_runner = auto_runner:new({ interval = 0.01 }),
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
    turn_runtime = {
      next_turn_locked = false,
      next_turn_last_click = nil,
      next_turn_lock_phase = nil,
      role_control_lock_active = false,
      role_control_lock_suppress = 0,
    },
    debug_runtime = {
      log_once = {},
    },
  }
  support.bind_ui_runtime(state)
  state.auto_runner:set_enabled(true)
  return state
end

local _t2_characterization_tests = {
  function()
    local player = { id = 1, name = "P1" }
    local phase_res = {
      next_state = "move",
      next_args = { player = player, total = 10 },
      wait_action_anim = true,
    }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 10, 5)
    assert(state == "wait_action_anim", "should return wait_action_anim state")
    assert(args.next_state == "move", "should preserve next_state")
    assert(args.next_args.total == 10, "should preserve total in next_args")
  end,
  function()
    local player = { id = 1, name = "P1" }
    local phase_res = {
      next_state = "land",
      next_args = { player = player, total = 8 },
      wait_action_anim = false,
    }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 8, 4)
    assert(state == "wait_choice", "should return wait_choice state when no anim wait")
    assert(args.next_state == "land", "should preserve next_state")
  end,
  function()
    local player = { id = 1, name = "P1" }
    local phase_res = {}
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 6, 3)
    assert(state == "wait_choice", "should default to wait_choice")
    assert(args.next_state == "move", "should default next_state to move")
    assert(args.next_args.player == player, "should include player in default next_args")
    assert(args.next_args.total == 6, "should include total in default next_args")
    assert(args.next_args.raw_total == 3, "should include raw_total in default next_args")
  end,
}

local _dispatch_validator_tests = {
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when actor matches owner")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local p2 = g.players[2]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p2.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when actor does not match owner")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1 }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when choice has no owner")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select" }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when action has no actor_role_id")
  end,
}

local _timer_policy_tests = {
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.phase = "start"
    local result = turn_timer_policy.is_afk_trackable_wait(g, state, ports)
    assert(result == true, "should be trackable during action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.phase = "wait_choice"
    state.ui = { choice_active = true }
    local result = turn_timer_policy.is_afk_trackable_wait(g, state, ports)
    assert(result == true, "should be trackable during wait_choice with choice active")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.phase = "move"
    state.ui = { choice_active = true }
    local result = turn_timer_policy.is_afk_trackable_wait(g, state, ports)
    assert(result == false, "should not be trackable when choice is active but phase is not wait_choice")
  end,
}

local _log_missing_auto_tests = {
  function()
    local g = _new_game()
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
    local g = _new_game()
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
    local g = _new_game()
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

local _roll_dice_tests = {
  function()
    local results, total = roll._roll_dice(3, { 4, 5, 6 }, nil)
    assert(#results == 3, "should return 3 results")
    assert(results[1] == 4 and results[2] == 5 and results[3] == 6, "should use override values")
    assert(total == 15, "total should sum override values")
  end,
  function()
    local results, total = roll._roll_dice(4, { 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 4, "should return 4 results")
    assert(results[1] == 2 and results[2] == 3, "should use provided overrides")
    assert(results[3] == 3 and results[4] == 3, "should repeat last override value")
  end,
  function()
    local results, total = roll._roll_dice(2, nil, { next_int = function() return 4 end })
    assert(#results == 2, "should return 2 results")
    assert(results[1] == 4 and results[2] == 4, "should use rng when no override")
    assert(total == 8, "total should sum rng values")
  end,
  function()
    local results, total = roll._roll_dice(1, {}, { next_int = function() return 3 end })
    assert(#results == 1, "should return 1 result")
    assert(results[1] == 3, "should use rng when override is empty table")
    assert(total == 3, "total should be rng value")
  end,
}

local land = require("src.game.flow.turn.land")
local _resolve_wait_state_tests = {
  function()
    local game = {
      turn = {},
      dirty = {},
    }
    local next_state, next_args = land._resolve_wait_state(game, "move", { player = { id = 1 } }, true)
    assert(next_state == "move", "should return next_state when no action anim and wait_action_anim is true")
  end,
  function()
    local game = {
      turn = { action_anim = { kind = "test" } },
      dirty = {},
    }
    local next_state, next_args = land._resolve_wait_state(game, "move", { player = { id = 1 } }, true)
    assert(next_state == "wait_action_anim", "should return wait_action_anim when action anim exists")
    assert(next_args.next_state == "move", "should preserve next_state in args")
  end,
  function()
    local game = {
      turn = {},
      dirty = {},
    }
    local landing_visual_hold = require("src.core.state_access.landing_visual_hold")
    landing_visual_hold.hold_state_for_game(game, { duration = 1.0 })
    local next_state, next_args = land._resolve_wait_state(game, "post_action", { player = { id = 1 } }, false)
    assert(next_state == "wait_landing_visual", "should return wait_landing_visual when landing visual hold is active")
    landing_visual_hold.release(game)
  end,
  function()
    local game = {
      turn = { action_anim_queue = { { kind = "move_effect" } } },
      dirty = {},
    }
    local next_state, next_args = land._resolve_wait_state(game, "post_action", { player = { id = 1 } }, false)
    assert(next_state == "wait_action_anim", "should return wait_action_anim when action anim queue has items")
  end,
}

local tick_timeout = require("src.game.flow.turn.tick_timeout")
local _resolve_choice_ui_state_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local result = tick_timeout.resolve_choice_ui_state(game, state)
    assert(result.route_key == nil, "should return nil route_key when no pending choice")
    assert(result.should_warn == false, "should not warn when no pending choice")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, route_key = "test_route" }
    local result = tick_timeout.resolve_choice_ui_state(game, state)
    assert(result.route_key == "test_route", "should return route_key from pending choice")
    assert(result.should_warn == false, "should not warn when choice has route_key")
  end,
}

local camera_policy = require("src.game.flow.turn.camera_policy")
local _resolve_follow_player_id_tests = {
  function()
    local game = _new_game()
    local result = camera_policy._resolve_follow_player_id(game)
    local p1 = game.players[1]
    assert(result == p1.id, "should return current player id when not eliminated")
  end,
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    local result = camera_policy._resolve_follow_player_id(game)
    local p2 = game.players[2]
    assert(result == p2.id, "should return next non-eliminated player")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = nil
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when no current player index")
  end,
  function()
    local game = _new_game()
    game.players = {}
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when no players")
  end,
}

local tick_ui_sync = require("src.game.flow.turn.tick_ui_sync")
local _update_countdown_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 5
    game.turn.detained_wait_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == 3, "should calculate remaining detained wait seconds")
    assert(game.turn.countdown_active == true, "should set countdown active for detained wait")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 1
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "should set countdown active for action button")
  end,
}

local _is_action_button_wait_active_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == true, "should be active when no blocking UI and game not finished")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    game.finished = true
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when game is finished")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    local result = turn_timer_policy.is_action_button_wait_active(game, state, ports)
    assert(result == false, "should not be active when input is blocked")
  end,
}

local choice_auto_policy = require("src.game.flow.turn.choice_auto_policy")
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

return {
  name = "gameplay_t2_characterization",
  tests = {
    { name = "_test_resolve_phase_wait_result_with_wait_action_anim", run = _t2_characterization_tests[1] },
    { name = "_test_resolve_phase_wait_result_without_wait_action_anim", run = _t2_characterization_tests[2] },
    { name = "_test_resolve_phase_wait_result_defaults", run = _t2_characterization_tests[3] },
    { name = "_test_dispatch_validator_validate_choice_actor_match", run = _dispatch_validator_tests[1] },
    { name = "_test_dispatch_validator_validate_choice_actor_mismatch", run = _dispatch_validator_tests[2] },
    { name = "_test_dispatch_validator_validate_choice_actor_no_owner", run = _dispatch_validator_tests[3] },
    { name = "_test_dispatch_validator_validate_choice_actor_no_actor_id", run = _dispatch_validator_tests[4] },
    { name = "_test_timer_policy_is_afk_trackable_wait_action_button", run = _timer_policy_tests[1] },
    { name = "_test_timer_policy_is_afk_trackable_wait_choice_phase", run = _timer_policy_tests[2] },
    { name = "_test_timer_policy_is_afk_trackable_not_in_wait_choice", run = _timer_policy_tests[3] },
    { name = "_test_log_missing_auto_choice_action_logs_once", run = _log_missing_auto_tests[1] },
    { name = "_test_log_missing_auto_choice_action_skips_when_waiting", run = _log_missing_auto_tests[2] },
    { name = "_test_log_missing_auto_choice_action_skips_when_not_auto", run = _log_missing_auto_tests[3] },
    { name = "_test_tick_choice_timeout_resolve_choice_owner_id_from_choice", run = _resolve_choice_owner_tests[1] },
    { name = "_test_tick_choice_timeout_resolve_choice_owner_id_fallback", run = _resolve_choice_owner_tests[2] },
    { name = "_test_tick_choice_timeout_resolve_choice_owner_id_not_found", run = _resolve_choice_owner_tests[3] },
    { name = "_test_roll_dice_with_override_uses_provided_values", run = _roll_dice_tests[1] },
    { name = "_test_roll_dice_with_partial_override_uses_last_for_remaining", run = _roll_dice_tests[2] },
    { name = "_test_roll_dice_with_rng_no_override", run = _roll_dice_tests[3] },
    { name = "_test_roll_dice_with_empty_override_uses_rng", run = _roll_dice_tests[4] },
    { name = "_test_resolve_wait_state_no_anim_wait_action_anim", run = _resolve_wait_state_tests[1] },
    { name = "_test_resolve_wait_state_with_action_anim_wait_action_anim", run = _resolve_wait_state_tests[2] },
    { name = "_test_resolve_wait_state_landing_visual_hold", run = _resolve_wait_state_tests[3] },
    { name = "_test_resolve_wait_state_with_action_anim_queue", run = _resolve_wait_state_tests[4] },
    { name = "_test_resolve_choice_ui_state_no_pending", run = _resolve_choice_ui_state_tests[1] },
    { name = "_test_resolve_choice_ui_state_with_pending", run = _resolve_choice_ui_state_tests[2] },
    { name = "_test_resolve_follow_player_id_current", run = _resolve_follow_player_id_tests[1] },
    { name = "_test_resolve_follow_player_id_next_non_eliminated", run = _resolve_follow_player_id_tests[2] },
    { name = "_test_resolve_follow_player_id_no_index", run = _resolve_follow_player_id_tests[3] },
    { name = "_test_resolve_follow_player_id_no_players", run = _resolve_follow_player_id_tests[4] },
    { name = "_test_update_countdown_detained_wait", run = _update_countdown_tests[1] },
    { name = "_test_update_countdown_action_button", run = _update_countdown_tests[2] },
    { name = "_test_is_action_button_wait_active_normal", run = _is_action_button_wait_active_tests[1] },
    { name = "_test_is_action_button_wait_active_finished", run = _is_action_button_wait_active_tests[2] },
    { name = "_test_is_action_button_wait_active_blocked", run = _is_action_button_wait_active_tests[3] },
    { name = "_test_choice_auto_policy_wait_choice_not_auto", run = _choice_auto_policy_tests[1] },
    { name = "_test_choice_auto_policy_preconsumed_item", run = _choice_auto_policy_tests[2] },
    { name = "_test_choice_auto_policy_timeout_cancel", run = _choice_auto_policy_tests[3] },
  },
}
