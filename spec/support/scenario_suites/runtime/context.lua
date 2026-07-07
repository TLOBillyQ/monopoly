local gameplay_cases = require("spec.support.scenario_suites.shared.cases")
local support = require("spec.support.shared_support")
local gameplay_loop_ports = require("src.turn.loop.ports")
local gameplay_loop = require("src.turn.loop")
local landing_visual_hold = support.landing_visual_hold
local wait_callbacks = require("src.turn.waits.callback_registry")
local turn_camera_policy = require("src.turn.policies.camera")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

-- 门控测试替身基于真实 gate 模块构建：键名→语义的映射不在这里重复。
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")
local _gate_common = {
  get_ui_state = function(state)
    return state and state.ui or nil
  end,
}

local function _build_test_ports(overrides)
  overrides = overrides or {}
  return gameplay_loop_ports.resolve({
    modal = {
      close_choice_modal = function() end,
      open_choice_modal = function() end,
      close_popup = function() end,
    },
    anim = {
      play_move_anim = function() return 0 end,
      play_action_anim = function() return 0 end,
      reset_status_3d = overrides.reset_status_3d or function() end,
      sync_status_3d = overrides.sync_status_3d or function() end,
    },
    ui_sync = {
      apply_input_lock = function() end,
      step_choice_timeout = function() end,
      step_modal_timeout = function() end,
      update_countdown = overrides.update_countdown or function() end,
      build_model = function() return nil end,
      refresh_from_dirty = overrides.refresh_from_dirty or function() return false end,
      follow_camera = overrides.follow_camera or function() return false end,
      get_ui_state = function(state)
        return _gate_common.get_ui_state(state)
      end,
      is_input_blocked = function(state)
        return ui_gate_sync.is_input_blocked(state, _gate_common)
      end,
      is_popup_active = function(state)
        return ui_gate_sync.is_popup_active(state, _gate_common)
      end,
      is_choice_active = function(state)
        return ui_gate_sync.is_choice_active(state, _gate_common)
      end,
      get_popup_owner_index = function(state)
        return ui_gate_sync.get_popup_owner_index(state, _gate_common)
      end,
      resolve_ui_gate = function(state)
        return ui_gate_sync.resolve_ui_gate(state, _gate_common)
      end,
      set_input_blocked = function(state, blocked)
        return ui_gate_sync.set_input_blocked(state, blocked, _gate_common)
      end,
    },
    debug = {
      log_status = function() end,
      sync_event_log = function() end,
      resolve_event_log_enabled = function() return false end,
    },
    clock = {
      wall_now_seconds = function() return 0 end,
      wall_diff_seconds = function(a, b) return (a or 0) - (b or 0) end,
      cpu_now_seconds = function() return 0 end,
      cpu_diff_seconds = function(a, b) return (a or 0) - (b or 0) end,
    },
    state = {
      apply_role_control_lock = function() end,
      install_event_handlers = function() end,
      on_bankruptcy_tiles_cleared = function() end,
    },
  })
end

local function _build_loop_state()
  local auto_runner = require("src.turn.policies.auto_runner")
  local ui_port = support.build_ui_port()
  local state = {
    gameplay_loop_ports = _build_test_ports(),
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

local function _test_landing_visual_release_flushes_before_scheduler_advances_turn()
  local game = support.new_game()
  local state = _build_loop_state()
  local sequence = {}

  state.gameplay_loop_ports = _build_test_ports({
    refresh_from_dirty = function()
      return false
    end,
  })

  gameplay_loop.set_game(state, game)
  game.turn.phase = "wait_landing_visual"
  landing_visual_hold.start(game)
  landing_visual_hold.mark_release_pending(game)
  game.turn.landing_visual_hold_active = false
  game.turn.landing_visual_release_pending = false
  landing_visual_hold.register_release_callback(state, "runtime_event", function()
    sequence[#sequence + 1] = "release"
  end)

  local seq = wait_callbacks.begin_wait(game, wait_callbacks.wait_keys.landing_visual)
  wait_callbacks.mark_wait_ready(game, wait_callbacks.wait_keys.landing_visual, seq)
  game.advance_turn = function()
    sequence[#sequence + 1] = "advance"
  end

  gameplay_loop.tick(game, state, 0.1)
  assert(sequence[1] == "release", "landing visual release should flush before any scheduler advance")
  assert(sequence[2] == nil, "landing visual release tick should not advance turn in the same frame")

  gameplay_loop.tick(game, state, 0.1)
  assert(sequence[2] == "advance", "scheduler should advance on the first tick after landing visual release")
end

  local function _test_camera_policy_retargets_when_player_changes_without_ui_refresh()
    local game = support.new_game()
    local state = {
      turn_runtime = {
        last_follow_player_id = nil,
      },
    }
    local followed = {}
    local ports = {
      ui_sync = {
        follow_camera = function(_, player_id)
          followed[#followed + 1] = player_id
        end,
      },
    }

    game.turn.current_player_index = 1
    turn_camera_policy.sync_follow(game, state, ports, true)
    game.turn.current_player_index = 2
    turn_camera_policy.sync_follow(game, state, ports, false)

    assert(followed[1] == game.players[1].id, "initial follow should target the current player")
    assert(followed[2] == game.players[2].id, "camera should retarget on player change even without a full ui refresh")
  end

local function _test_camera_sync_other_path_calls_set_camera_property_after_lock()
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local runtime_state = require("src.state.runtime")
  local camera_sync = require("src.ui.ports.ui_sync")._camera

  -- Track set_camera_property calls
  local set_camera_property_calls = {}
  local set_camera_lock_position_called = false

  -- Mock local_role
  local local_role = {
    set_camera_lock_position = function(pos)
      set_camera_lock_position_called = true
      return nil
    end,
    set_camera_property = function(prop, value)
      set_camera_property_calls[#set_camera_property_calls + 1] = { prop, value }
      return nil
    end,
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 0, y = 0, z = 0 }
        end,
      }
    end,
    get_camera_direction = function()
      return { x = 0, y = 0, z = 1 }
    end,
    reset_camera = function()
      return nil
    end,
  }

  -- Mock target_role
  local target_role = {
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 1, y = 1, z = 1 }
        end,
      }
    end,
  }

  -- Mock state with ui_runtime and local_actor_role_id
  local state = {
    ui = {},
  }
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.local_actor_role_id = 1

  -- Configure runtime_ports with mocks
  runtime_ports.configure({
    resolve_role = function(player_id)
      if player_id == 1 then
        return local_role
      elseif player_id == 2 then
        return target_role
      end
      return nil
    end,
    resolve_camera_helper = function()
      return { target_role_id = nil, follow = function() end }
    end,
  })

  local ok, err = pcall(function()
    -- Call follow_camera with player_id=2 (OTHER path)
    local result = camera_sync.follow_camera(state, 2)

    -- Assertions
    assert(result == true, "follow_camera should succeed when presentation follow target exists")
    assert(result == true, "follow_camera should succeed when presentation follow target exists")
    assert(set_camera_lock_position_called == true, "set_camera_lock_position should be called in OTHER path")

    local has_dist = false
    local has_height = false
    local has_pitch = false
    local has_yaw = false

    for _, call in ipairs(set_camera_property_calls) do
      if call[1] == 7 and call[2] == 30 then has_dist = true end
      if call[1] == 11 and call[2] == 10 then has_height = true end
      if call[1] == 15 and call[2] == 45 then has_pitch = true end
      if call[1] == 16 and call[2] == -90 then has_yaw = true end
    end

    assert(has_dist, "set_camera_property should be called with DIST (7, 30)")
    assert(has_height, "set_camera_property should be called with OBSERVER_HEIGHT (11, 10)")
    assert(has_pitch, "set_camera_property should be called with PITCH (15, 45)")
    assert(has_yaw, "set_camera_property should be called with YAW (16, -90)")
  end)

  -- Cleanup - CRITICAL: always reset ports even if test fails
  runtime_ports.reset_for_tests()

  if not ok then
    error(err)
  end
end

local function _test_camera_sync_prefers_presentation_follow_target_over_ctrl_unit()
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local runtime_state = require("src.state.runtime")
  local camera_sync = require("src.ui.ports.ui_sync")._camera

  local locked_positions = {}
  local local_role = {
    set_camera_lock_position = function(pos)
      locked_positions[#locked_positions + 1] = pos
      return nil
    end,
    set_camera_property = function() return nil end,
    reset_camera = function()
      return nil
    end,
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 0, y = 0, z = 0 }
        end,
      }
    end,
  }

  local target_role = {
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 99, y = 99, z = 99 }
        end,
      }
    end,
  }

  local state = {
    ui = {},
  }
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.local_actor_role_id = 1
  runtime_state.set_follow_target_position(state, 2, { x = 12, y = 34, z = 56 }, {
    source = "test",
    seq = 7,
  })

  runtime_ports.configure({
    resolve_role = function(player_id)
      if player_id == 1 then
        return local_role
      elseif player_id == 2 then
        return target_role
      end
      return nil
    end,
    resolve_camera_helper = function()
      return { target_role_id = nil, follow = function() end }
    end,
  })

  local ok, err = pcall(function()
    local result = camera_sync.follow_camera(state, 2)
    assert(result == true, "follow_camera should succeed when presentation follow target exists")
    assert(#locked_positions == 1, "follow_camera should lock once")
    assert(locked_positions[1].x == 12, "follow_camera should prefer presentation follow target x")
    assert(locked_positions[1].y == 34, "follow_camera should prefer presentation follow target y")
    assert(locked_positions[1].z == 56, "follow_camera should prefer presentation follow target z")
  end)

  runtime_ports.reset_for_tests()

  if not ok then
    error(err)
  end
end

local function _test_camera_sync_self_path_does_not_call_set_camera_property()
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local runtime_state = require("src.state.runtime")
  local camera_sync = require("src.ui.ports.ui_sync")._camera

  -- Track set_camera_property calls
  local set_camera_property_calls = {}
  local reset_camera_called = false

  -- Mock local_role
  local local_role = {
    set_camera_lock_position = function(pos)
      return nil
    end,
    set_camera_property = function(prop, value)
      set_camera_property_calls[#set_camera_property_calls + 1] = { prop, value }
      return nil
    end,
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 0, y = 0, z = 0 }
        end,
      }
    end,
    get_camera_direction = function()
      return { x = 0, y = 0, z = 1 }
    end,
    reset_camera = function(a, b, c, d)
      reset_camera_called = true
      return nil
    end,
  }

  -- Mock state with ui_runtime and local_actor_role_id
  local state = {
    ui = {},
  }
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.local_actor_role_id = 1

  -- Configure runtime_ports with mocks
  runtime_ports.configure({
    resolve_role = function(player_id)
      if player_id == 1 then
        return local_role
      end
      return nil
    end,
    resolve_camera_helper = function()
      return { target_role_id = nil, follow = function() end }
    end,
  })

  local ok, err = pcall(function()
    -- Call follow_camera with player_id=1 (SELF path)
    local result = camera_sync.follow_camera(state, 1)

    -- Assertions
    assert(result == true, "follow_camera should succeed in SELF path")
    assert(result == true, "follow_camera should succeed in SELF path")
    assert(reset_camera_called == true, "reset_camera should be called in SELF path")
    assert(#set_camera_property_calls == 0, "set_camera_property should NOT be called in SELF path")
  end)

  -- Cleanup - CRITICAL: always reset ports even if test fails
  runtime_ports.reset_for_tests()

  if not ok then
    error(err)
  end
end

local function _test_camera_sync_sync_camera_position_also_restores_props()
  local runtime_ports = require("src.foundation.ports.runtime_ports")
  local runtime_state = require("src.state.runtime")
  local camera_sync = require("src.ui.ports.ui_sync")._camera

  -- Track set_camera_property calls
  local set_camera_property_calls = {}

  -- Mock local_role
  local local_role = {
    set_camera_lock_position = function(pos)
      return nil
    end,
    set_camera_property = function(prop, value)
      set_camera_property_calls[#set_camera_property_calls + 1] = { prop, value }
      return nil
    end,
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 0, y = 0, z = 0 }
        end,
      }
    end,
    get_camera_direction = function()
      return { x = 0, y = 0, z = 1 }
    end,
    reset_camera = function()
      return nil
    end,
  }

  -- Mock target_role
  local target_role = {
    get_ctrl_unit = function()
      return {
        get_position = function()
          return { x = 2, y = 2, z = 2 }
        end,
      }
    end,
  }

  -- Mock state with ui_runtime and local_actor_role_id
  local state = {
    ui = {},
  }
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  ui_runtime.local_actor_role_id = 1

  -- Configure runtime_ports with mocks
  runtime_ports.configure({
    resolve_role = function(player_id)
      if player_id == 1 then
        return local_role
      elseif player_id == 2 then
        return target_role
      end
      return nil
    end,
    resolve_camera_helper = function()
      return { target_role_id = 2, follow = function() end }
    end,
  })

  local ok, err = pcall(function()
    -- Call sync_camera_position
    camera_sync.sync_camera_position(state)

    -- Assertions
    local has_dist = false
    for _, call in ipairs(set_camera_property_calls) do
      if call[1] == 7 and call[2] == 30 then has_dist = true end
    end

    assert(has_dist, "set_camera_property should be called with DIST (7, 30) in sync_camera_position")
  end)

  -- Cleanup - CRITICAL: always reset ports even if test fails
  runtime_ports.reset_for_tests()

  if not ok then
    error(err)
  end
end

return {
  name = "gameplay_runtime_context_and_camera_sync",
  tests = {
    _case("_test_runtime_context_split_install_stages"),
    _case("_test_runtime_context_install_helpers_without_globals"),
    _case("_test_runtime_context_install_environment_fails_fast"),
    _case("_test_game_startup_build_state_is_pure_and_bridge_installs_events"),
    _case("_test_turn_dispatch_uses_clock_ports_without_game_api"),
    _case("_test_gameplay_loop_set_game_uses_narrow_runtime_ports"),
    _case("_test_gameplay_loop_refresh_drives_camera_follow_via_port"),
    _case("_test_gameplay_loop_camera_follow_skips_eliminated_current_player"),
    _case("_test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics"),
    _case("_test_game_startup_role_roster_retries_before_debug_players_fallback"),
    _case("_test_find_player_by_id_accepts_mixed_representation"),
    { name = "landing_visual_release_flushes_before_scheduler_advances_turn", run = _test_landing_visual_release_flushes_before_scheduler_advances_turn },
    { name = "camera_policy_retargets_when_player_changes_without_ui_refresh", run = _test_camera_policy_retargets_when_player_changes_without_ui_refresh },
    { name = "camera_sync_other_path_calls_set_camera_property_after_lock", run = _test_camera_sync_other_path_calls_set_camera_property_after_lock },
    { name = "camera_sync_prefers_presentation_follow_target_over_ctrl_unit", run = _test_camera_sync_prefers_presentation_follow_target_over_ctrl_unit },
    { name = "camera_sync_self_path_does_not_call_set_camera_property", run = _test_camera_sync_self_path_does_not_call_set_camera_property },
    { name = "camera_sync_sync_camera_position_also_restores_props", run = _test_camera_sync_sync_camera_position_also_restores_props },
  },
}
