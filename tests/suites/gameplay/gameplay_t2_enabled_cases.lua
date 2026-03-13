local support = require("support.gameplay_support")
local runtime_state = require("src.core.state_access.runtime_state")
local tick_choice_timeout = require("src.game.flow.turn.waits.choice_timeout")
local tick_ui_sync = require("src.game.flow.turn.waits.ui_sync")
local turn_timer_policy = require("src.game.flow.turn.policies.timer_policy")
local turn_camera_policy = require("src.game.flow.turn.policies.camera_policy")
local loop_ui_sync_defaults = require("src.game.flow.turn.runtime.ui_sync_defaults")
local roll = require("src.game.flow.turn.phases.roll")

local _new_game = support.new_game
local _build_ui_port = support.build_ui_port

local function _build_test_ports(overrides)
  overrides = overrides or {}
  return {
    ui_sync = {
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
    },
  }
end

local function _build_loop_state()
  local auto_runner = require("src.game.flow.turn.auto.runner")
  local ui_port = _build_ui_port()
  local state = {
    gameplay_loop_ports = {
      output = {},
    },
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

local function _with_reloaded_move_module(movement_stub, followup_stub, fn)
  local original_movement = package.loaded["src.game.systems.movement"]
  local original_followup = package.loaded["src.game.flow.turn.phases.move_followup"]
  local original_move = package.loaded["src.game.flow.turn.phases.move"]
  package.loaded["src.game.systems.movement"] = movement_stub
  package.loaded["src.game.flow.turn.phases.move_followup"] = followup_stub
  package.loaded["src.game.flow.turn.phases.move"] = nil
  local ok, result = pcall(function()
    return fn(require("src.game.flow.turn.phases.move"))
  end)
  package.loaded["src.game.systems.movement"] = original_movement
  package.loaded["src.game.flow.turn.phases.move_followup"] = original_followup
  package.loaded["src.game.flow.turn.phases.move"] = original_move
  if not ok then
    error(result)
  end
  return result
end

return {
  _test_roll_dice_with_rng_only = function()
    local results, total = roll._roll_dice(2, nil, { next_int = function() return 5 end })
    assert(#results == 2 and results[1] == 5 and results[2] == 5, "rng path should cover all dice")
    assert(total == 10, "rng path should sum results")
  end,
  _test_roll_dice_zero_count = function()
    local results, total = roll._roll_dice(0, nil, { next_int = function() return 3 end })
    assert(#results == 0, "zero dice should return empty result")
    assert(total == 0, "zero dice should have zero total")
  end,
  _test_roll_dice_truncates_extra_overrides = function()
    local results, total = roll._roll_dice(2, { 1, 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 2 and results[1] == 1 and results[2] == 2, "extra overrides should be ignored")
    assert(total == 3, "total should only sum used overrides")
  end,
  _test_roll_dice_exact_override_match = function()
    local results, total = roll._roll_dice(3, { 2, 4, 6 }, { next_int = function() return 1 end })
    assert(#results == 3 and results[3] == 6, "exact overrides should be preserved")
    assert(total == 12, "exact overrides should sum correctly")
  end,
  _test_apply_dice_multiplier_applies_and_resets = function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 4 } }
    local turn_mgr = {
      game = {
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function(_, target, key, value)
          target.status[key] = value
        end,
      },
    }
    local called_total = nil
    local result = _with_reloaded_move_module({
      move = function(_, _, total)
        called_total = total
        return { visited = {}, steps = {} }
      end,
    }, {
      run = function() return "move_ok" end,
    }, function(move_module)
      return move_module(turn_mgr, { player = player, total = 3, raw_total = 3 })
    end)
    assert(result == "move_ok", "move should finish through followup")
    assert(called_total == 12, "multiplier should be applied")
    assert(player.status.pending_dice_multiplier == 1, "multiplier should be reset")
  end,
  _test_apply_dice_multiplier_skips_when_total_changed = function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 2 } }
    local turn_mgr = {
      game = {
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function() end,
      },
    }
    local called_total = nil
    _with_reloaded_move_module({
      move = function(_, _, total)
        called_total = total
        return { visited = {}, steps = {} }
      end,
    }, {
      run = function() return "move_ok" end,
    }, function(move_module)
      return move_module(turn_mgr, { player = player, total = 10, raw_total = 8 })
    end)
    assert(called_total == 10, "multiplier should be skipped when total already changed")
  end,
  _test_apply_dice_multiplier_skips_when_raw_total_nil = function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 3 } }
    local turn_mgr = {
      game = {
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function() end,
      },
    }
    local called_total = nil
    _with_reloaded_move_module({
      move = function(_, _, total)
        called_total = total
        return { visited = {}, steps = {} }
      end,
    }, {
      run = function() return "move_ok" end,
    }, function(move_module)
      return move_module(turn_mgr, { player = player, total = 6, raw_total = nil })
    end)
    assert(called_total == 6, "multiplier should be skipped when raw_total is nil")
  end,
  _test_resolve_choice_owner_id_fallback_current = function()
    local g = _new_game()
    g.turn.current_player_index = 2
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1, owner_role_id = 999 })
    assert(result == g.players[2].id, "missing owner should fall back to current player")
  end,
  _test_resolve_choice_owner_id_out_of_range = function()
    local g = _new_game()
    g.turn.current_player_index = 5
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1 })
    assert(result == nil, "out-of-range current player should return nil")
  end,
  _test_resolve_choice_owner_missing_find_player = function()
    local g = _new_game()
    g.find_player_by_id = nil
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1, owner_role_id = g.players[1].id })
    assert(result == g.players[1].id, "missing finder should still fall back to current player")
  end,
  _test_resolve_choice_owner_no_players = function()
    local g = _new_game()
    g.players = nil
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1 })
    assert(result == nil, "missing players should return nil")
  end,
  _test_resolve_follow_player_id_skip_nil_id = function()
    local game = _new_game()
    game.players[1].id = nil
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[2].id, "current player with nil id should be skipped")
  end,
  _test_resolve_follow_player_id_wrap_around = function()
    local game = _new_game()
    game.turn.current_player_index = 2
    game.players[2].eliminated = true
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[1].id, "search should wrap to next live player")
  end,
  _test_resolve_follow_player_id_all_eliminated = function()
    local game = _new_game()
    game.players[1].eliminated = true
    game.players[2].eliminated = true
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "all eliminated players should return nil")
  end,
  _test_resolve_follow_player_id_nil_turn = function()
    local game = _new_game()
    game.turn = nil
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "missing turn should return nil")
  end,
  _test_resolve_follow_player_id_empty_players = function()
    local game = _new_game()
    game.players = {}
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "empty players should return nil")
  end,
  _test_resolve_wait_state_prefers_wait_action_anim = function()
    local game = { turn = { action_anim = { kind = "test" } }, dirty = {} }
    local state_name = require("src.game.flow.turn.phases.land")._resolve_wait_state(game, "post_action", { player = { id = 1 } }, true)
    assert(state_name == "wait_action_anim", "wait_action_anim should win when requested")
  end,
  _test_resolve_wait_state_without_anim_returns_wait_choice = function()
    local game = { turn = {}, dirty = {} }
    local state_name, args = require("src.game.flow.turn.phases.land")._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(state_name == "wait_choice", "no action anim should still route through wait_choice")
    assert(args.next_state == "move", "next state should be preserved")
  end,
  _test_resolve_wait_state_wraps_move_effect_queue = function()
    local game = { turn = { action_anim_queue = { { kind = "move_effect" } } }, dirty = {} }
    local state_name, args = require("src.game.flow.turn.phases.land")._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(state_name == "wait_action_anim", "queued move effect should wait for action anim")
    assert(args.next_state == "wait_choice", "non-anim wait should wrap back to wait_choice")
  end,
  _test_fill_ui_sync_defaults_fills_all = function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(type(ports.resolve_ui_gate) == "function", "defaults should be filled")
    assert(type(ports.set_input_blocked) == "function", "set_input_blocked default should be filled")
  end,
  _test_fill_ui_sync_defaults_preserves_custom = function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    ports.get_ui_state = function() return "custom" end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(ports.get_ui_state() == "custom", "custom port should be preserved")
    assert(type(ports.is_popup_active) == "function", "missing ports should still be filled")
  end,
  _test_fill_ui_sync_defaults_resolve_ui_gate = function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = true, popup_active = true, market_active = true, popup_payload = { auto_close_seconds = 10 } } }
    local gate = ports.resolve_ui_gate(state)
    assert(gate.input_blocked == true and gate.market_active == true, "ui gate should mirror ui state")
    assert(gate.popup_auto_close_seconds == 10, "ui gate should expose popup timeout")
  end,
  _test_fill_ui_sync_defaults_set_input_blocked = function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local state = { ui = { input_blocked = false } }
    assert(ports.set_input_blocked(state, true) == true, "setter should report change")
    assert(ports.set_input_blocked(state, true) == false, "setter should report no-op")
  end,
  _test_fill_ui_sync_defaults_gate_nil_state = function()
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local gate = ports.resolve_ui_gate(nil)
    assert(gate.popup_seq == nil and gate.popup_active == false, "nil state should produce empty ui gate")
  end,
  _test_update_countdown_pending_choice = function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.pending_choice = { id = 1, kind = "test" }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "pending choice should activate countdown")
  end,
  _test_update_countdown_detained_wait = function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 10
    game.turn.detained_wait_elapsed = 3
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == 7, "detained wait should count down remaining seconds")
  end,
  _test_update_countdown_action_button = function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "action button timer should activate countdown")
  end,
  _test_update_countdown_popup_zero_timeout = function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 0 } }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == false or game.turn.countdown_active == true, "popup path should not error")
  end,
  _test_is_action_button_wait_active_pending_choice = function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.pending_choice = { id = 1 }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "pending choice should block action button wait")
  end,
  _test_is_action_button_wait_active_input_blocked = function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "input blocked ui should block action button wait")
  end,
  _test_is_action_button_wait_active_popup = function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { popup_active = true }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "popup should block action button wait")
  end,
  _test_is_action_button_wait_active_finished_game = function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.finished = true
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "finished game should block action button wait")
  end,
}
