local support = require("support.gameplay_support")
local gameplay_loop_ports = require("src.turn.loop.ports")
local gameplay_loop = support.gameplay_loop
local landing_visual_hold = support.landing_visual_hold
local wait_callbacks = require("src.turn.waits.callback_registry")
local turn_camera_policy = require("src.turn.policies.camera_policy")

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
      get_ui_state = function(state) return state and state.ui or nil end,
      is_input_blocked = function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
      get_popup_owner_index = function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_owner_index or nil
      end,
      set_input_blocked = function(state, blocked)
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
      log_status = function() end,
      sync_debug_log = function() end,
      resolve_debug_enabled = function() return false end,
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

local function _test_camera_policy_continues_follow_for_same_player_each_tick()
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
        return true
      end,
    },
  }

  game.turn.current_player_index = 1
  turn_camera_policy.sync_follow(game, state, ports, true)
  turn_camera_policy.sync_follow(game, state, ports, false)

  assert(#followed == 2, "camera should keep following every tick for the same player")
  assert(followed[1] == game.players[1].id, "first follow should target current player")
  assert(followed[2] == game.players[1].id, "second follow should keep targeting current player")
end

local function _test_camera_policy_retries_when_follow_camera_fails()
  local game = support.new_game()
  local state = {
    turn_runtime = {
      last_follow_player_id = nil,
    },
  }
  local followed = {}
  local call_count = 0
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        call_count = call_count + 1
        followed[#followed + 1] = player_id
        if call_count == 1 then
          return false
        end
        return true
      end,
    },
  }

  game.turn.current_player_index = 1
  turn_camera_policy.sync_follow(game, state, ports, true)
  assert(state.turn_runtime.last_follow_player_id == nil, "failed follow should not cache player id")

  turn_camera_policy.sync_follow(game, state, ports, false)
  assert(#followed == 2, "camera should retry follow after failure")
  assert(followed[1] == game.players[1].id, "first follow should target current player")
  assert(followed[2] == game.players[1].id, "retry follow should keep targeting current player")
  assert(state.turn_runtime.last_follow_player_id == game.players[1].id,
    "successful retry should cache current player id")
end

return {
  name = "gameplay_landing_visual_release_and_camera_follow",
  tests = {
    {
      name = "landing_visual_release_flushes_before_scheduler_advances_turn",
      run = _test_landing_visual_release_flushes_before_scheduler_advances_turn,
    },
    {
      name = "camera_policy_retargets_when_player_changes_without_ui_refresh",
      run = _test_camera_policy_retargets_when_player_changes_without_ui_refresh,
    },
    {
      name = "camera_policy_continues_follow_for_same_player_each_tick",
      run = _test_camera_policy_continues_follow_for_same_player_each_tick,
    },
    {
      name = "camera_policy_retries_when_follow_camera_fails",
      run = _test_camera_policy_retries_when_follow_camera_fails,
    },
  },
}
