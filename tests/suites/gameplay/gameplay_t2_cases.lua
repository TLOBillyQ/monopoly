local support = require("support.gameplay_support")
local _new_game = support.new_game
local _build_ui_port = support.build_ui_port
local _bind_ui_runtime = support.bind_ui_runtime
local roll = require("src.turn.phases.roll")
local tick_choice_timeout = require("src.turn.waits.choice_timeout")
local turn_camera_policy = require("src.turn.policies.camera_policy")
local tick_ui_sync = require("src.turn.waits.ui_sync")
local turn_timer_policy = require("src.turn.policies.timer_policy")

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
        if GameAPI and type(GameAPI.get_timestamp) == "function" then
          return GameAPI.get_timestamp()
        end
        return 0
      end,
      wall_diff_seconds = overrides.wall_diff_seconds or function(timestamp_1, timestamp_2)
        if GameAPI and type(GameAPI.get_timestamp_diff) == "function" then
          return GameAPI.get_timestamp_diff(timestamp_1, timestamp_2)
        end
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
  local auto_runner = require("src.turn.policies.auto_runner")
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
  _bind_ui_runtime(state)
  state.auto_runner:set_enabled(true)
  return state
end

local _t2_case_groups = {}

_t2_case_groups.roll_dice_tests = {
  function()
    local results, total = roll._roll_dice(3, { 4, 5, 6 }, nil)
    assert(#results == 3, "should return 3 results")
    assert(results[1] == 4 and results[2] == 5 and results[3] == 6, "should use override values")
    assert(total == 15, "total should sum override values")
  end,
  function()
    local results = roll._roll_dice(4, { 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 4, "should return 4 results")
    assert(results[1] == 2 and results[2] == 3, "should use provided overrides")
    assert(results[3] == 3 and results[4] == 3, "should repeat last override value")
  end,
}

local function _with_reloaded_move_module(movement_stub, followup_stub, fn)
  local original_movement = package.loaded["src.rules.movement"]
  local original_followup = package.loaded["src.turn.phases.move_followup"]
  local original_move = package.loaded["src.turn.phases.move"]
  package.loaded["src.rules.movement"] = movement_stub
  package.loaded["src.turn.phases.move_followup"] = followup_stub
  package.loaded["src.turn.phases.move"] = nil
  local ok, result = pcall(function()
    return fn(require("src.turn.phases.move"))
  end)
  package.loaded["src.rules.movement"] = original_movement
  package.loaded["src.turn.phases.move_followup"] = original_followup
  package.loaded["src.turn.phases.move"] = original_move
  if not ok then
    error(result)
  end
  return result
end

_t2_case_groups.apply_dice_multiplier_tests = {
  function()
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
      return move_module(turn_mgr, {
        player = player,
        total = 3,
        raw_total = 3,
      })
    end)
    assert(result == "move_ok", "move should finish through followup")
    assert(called_total == 12, "multiplier should be applied when total equals raw_total")
    assert(player.status.pending_dice_multiplier == 1, "multiplier should be reset")
  end,
  function()
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
      return move_module(turn_mgr, {
        player = player,
        total = 10,
        raw_total = 8,
      })
    end)
    assert(called_total == 10, "multiplier should be skipped when total already changed")
  end,
  function()
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
      return move_module(turn_mgr, {
        player = player,
        total = 6,
        raw_total = nil,
      })
    end)
    assert(called_total == 6, "multiplier should be skipped when raw_total is nil")
  end,
}

_t2_case_groups.roll_dice_extended_tests = {
  function()
    local results, total = roll._roll_dice(2, nil, { next_int = function() return 5 end })
    assert(#results == 2 and results[1] == 5 and results[2] == 5, "rng path should cover all dice")
    assert(total == 10, "rng path should sum results")
  end,
  function()
    local results, total = roll._roll_dice(0, nil, { next_int = function() return 3 end })
    assert(#results == 0, "zero dice should return empty result")
    assert(total == 0, "zero dice should have zero total")
  end,
  function()
    local results, total = roll._roll_dice(2, { 1, 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 2 and results[1] == 1 and results[2] == 2, "extra overrides should be ignored")
    assert(total == 3, "total should only sum used overrides")
  end,
  function()
    local results, total = roll._roll_dice(3, { 2, 4, 6 }, { next_int = function() return 1 end })
    assert(#results == 3 and results[3] == 6, "exact overrides should be preserved")
    assert(total == 12, "exact overrides should sum correctly")
  end,
}

_t2_case_groups.resolve_choice_owner_id_tests = {
  function()
    local g = _new_game()
    g.turn.current_player_index = 2
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1, owner_role_id = 999 })
    assert(result == g.players[2].id, "missing owner should fall back to current player")
  end,
  function()
    local g = _new_game()
    g.turn.current_player_index = 5
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1 })
    assert(result == nil, "out-of-range current player should return nil")
  end,
  function()
    local g = _new_game()
    g.find_player_by_id = nil
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1, owner_role_id = g.players[1].id })
    assert(result == g.players[1].id, "missing finder should still fall back to current player")
  end,
  function()
    local g = _new_game()
    g.players = nil
    local result = tick_choice_timeout._resolve_choice_owner_id(g, { id = 1 })
    assert(result == nil, "missing players should return nil")
  end,
}

_t2_case_groups.resolve_follow_player_id_tests = {
  function()
    local game = _new_game()
    game.players[1].id = nil
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[2].id, "current player with nil id should be skipped")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = 2
    game.players[2].eliminated = true
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[1].id, "search should wrap to next live player")
  end,
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    game.players[2].eliminated = true
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "all eliminated players should return nil")
  end,
  function()
    local game = _new_game()
    game.turn = nil
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "missing turn should return nil")
  end,
  function()
    local game = _new_game()
    game.players = {}
    local result = turn_camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "empty players should return nil")
  end,
}

_t2_case_groups.resolve_wait_state_tests = {
  function()
    local game = { turn = { action_anim = { kind = "test" } }, dirty = {} }
    local state_name = require("src.turn.phases.land")._resolve_wait_state(game, "post_action", { player = { id = 1 } }, true)
    assert(state_name == "wait_action_anim", "wait_action_anim should win when requested")
  end,
  function()
    local game = { turn = {}, dirty = {} }
    local state_name, args = require("src.turn.phases.land")._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(state_name == "wait_choice", "no action anim should still route through wait_choice")
    assert(args.next_state == "move", "next state should be preserved")
  end,
  function()
    local game = { turn = { action_anim_queue = { { kind = "move_effect" } } }, dirty = {} }
    local state_name, args = require("src.turn.phases.land")._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(state_name == "wait_action_anim", "queued move effect should wait for action anim")
    assert(args.next_state == "wait_choice", "non-anim wait should wrap back to wait_choice")
  end,
}

_t2_case_groups.fill_ui_sync_defaults_tests = {
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(type(ports.resolve_ui_gate) == "function", "defaults should be filled")
    assert(type(ports.set_input_blocked) == "function", "set_input_blocked default should be filled")
  end,
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
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
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
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
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
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
  function()
    local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() return {} end, function() return {} end)
    local ports = {}
    for key, value in pairs(base) do
      ports[key] = value
    end
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    local gate = ports.resolve_ui_gate(nil)
    assert(gate.popup_seq == nil and gate.popup_active == false, "nil state should produce empty ui gate")
  end,
}

_t2_case_groups.update_countdown_tests = {
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.current_player_index = 2
    game.turn.pending_choice = { id = 1, kind = "test", owner_role_id = game.players[2].id }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "pending choice should activate countdown")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    game.turn.detained_wait_active = true
    game.turn.detained_wait_seconds = 10
    game.turn.detained_wait_elapsed = 3
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_seconds == 7, "detained wait should count down remaining seconds")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.action_button_active = true
    state.action_button_elapsed = 2
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == true, "action button timer should activate countdown")
  end,
  function()
    local game = _new_game()
    local state = _build_loop_state()
    state.ui = { popup_active = true, popup_payload = { auto_close_seconds = 0 } }
    tick_ui_sync.update_countdown(game, state)
    assert(game.turn.countdown_active == false or game.turn.countdown_active == true, "popup path should not error")
  end,
}

_t2_case_groups.is_action_button_wait_active_tests = {
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.turn.pending_choice = { id = 1 }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "pending choice should block action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { input_blocked = true }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "input blocked ui should block action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    state.ui = { popup_active = true }
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "popup should block action button wait")
  end,
  function()
    local g = _new_game()
    local state = _build_loop_state()
    local ports = _build_test_ports()
    g.finished = true
    assert(turn_timer_policy.is_action_button_wait_active(g, state, ports) == false,
      "finished game should block action button wait")
  end,
}

return {
  case_groups = _t2_case_groups,
  with_reloaded_move_module = _with_reloaded_move_module,
}
