---@diagnostic disable
-- luacheck: ignore 113 211
local function make_cases(helpers)
  local _ENV = helpers

local function _test_tick_headless_ports_cover_anim_phases()
  local g = _new_game()
  local state = _build_loop_state()
  state.ui = nil
  state.wait_move_anim = true
  state.wait_action_anim = true
  local dispatched = {}
  local sequence = {}
  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local calls = {
    move_anim = 0,
    action_anim = 0,
    countdown = 0,
    refresh = 0,
  }

  state.gameplay_loop_ports = _build_test_ports({
    play_move_anim = function(_, anim_ctx)
      calls.move_anim = calls.move_anim + 1
      sequence[#sequence + 1] = "play_move_anim"
      assert(anim_ctx and anim_ctx.seq == 101, "move anim ctx should be injected")
      return 0
    end,
    play_action_anim = function(_, anim_ctx)
      calls.action_anim = calls.action_anim + 1
      sequence[#sequence + 1] = "play_action_anim"
      assert(anim_ctx and anim_ctx.seq == 201, "action anim ctx should be injected")
      return 0
    end,
    step_choice_timeout = function()
      sequence[#sequence + 1] = "step_choice_timeout"
    end,
    step_modal_timeout = function()
      sequence[#sequence + 1] = "step_modal_timeout"
    end,
    update_countdown = function()
      calls.countdown = calls.countdown + 1
      sequence[#sequence + 1] = "update_countdown"
    end,
    refresh_from_dirty = function()
      calls.refresh = calls.refresh + 1
      sequence[#sequence + 1] = "refresh_from_dirty"
      return false
    end,
    sync_event_log = function()
      sequence[#sequence + 1] = "sync_event_log"
    end,
    log_status = function()
      sequence[#sequence + 1] = "log_status"
    end,
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  g.turn.phase = "wait_move_anim"
  g.turn.move_anim = { seq = 101 }
  support.with_patches({
    { target = gameplay_loop, key = "step_auto_runner", value = function()
      sequence[#sequence + 1] = "step_auto_runner"
    end },
    { target = gameplay_loop_runtime, key = "sync_input_blocked", value = function()
      sequence[#sequence + 1] = "sync_input_blocked"
      return false
    end },
    { target = gameplay_loop_runtime, key = "sync_phase_flags", value = function()
      sequence[#sequence + 1] = "sync_phase_flags"
    end },
    { target = turn_role_control_policy, key = "sync", value = function()
      sequence[#sequence + 1] = "sync_role_control"
    end },
    { target = turn_timer_policy, key = "update_action_button_timer", value = function()
      sequence[#sequence + 1] = "update_action_button_timer"
    end },
    { target = turn_timer_policy, key = "update_detained_wait_timer", value = function()
      sequence[#sequence + 1] = "update_detained_wait_timer"
    end },
    { target = turn_timer_policy, key = "update_inter_turn_wait_timer", value = function()
      sequence[#sequence + 1] = "update_inter_turn_wait_timer"
    end },
    { target = turn_camera_policy, key = "sync_follow", value = function()
      sequence[#sequence + 1] = "sync_follow"
    end },
  }, function()
    gameplay_loop.tick(g, state, 0.1)
  end)
  assert(calls.move_anim == 1, "headless move anim should use injected port")
  assert(dispatched[1] and dispatched[1].type == "move_anim_done", "move anim should dispatch move_anim_done")
  assert(dispatched[1] and dispatched[1].seq == 101, "move anim seq should be forwarded")

  g.turn.phase = "wait_action_anim"
  g.turn.action_anim = { seq = 201 }
  support.with_patches({
    { target = gameplay_loop, key = "step_auto_runner", value = function()
      sequence[#sequence + 1] = "step_auto_runner"
    end },
  }, function()
    gameplay_loop.tick(g, state, 0.1)
  end)
  assert(calls.action_anim == 1, "headless action anim should use injected port")
  assert(dispatched[2] and dispatched[2].type == "action_anim_done", "action anim should dispatch action_anim_done")
  assert(dispatched[2] and dispatched[2].seq == 201, "action anim seq should be forwarded")

  assert(calls.countdown >= 2, "countdown should still step under custom ports")
  assert(calls.refresh >= 2, "refresh_from_dirty should still be called under custom ports")

  local expected_order = {
    "sync_input_blocked",
    "sync_role_control",
    "step_auto_runner",
    "step_choice_timeout",
    "step_modal_timeout",
    "update_action_button_timer",
    "update_detained_wait_timer",
    "update_inter_turn_wait_timer",
    "sync_input_blocked",
    "play_move_anim",
    "sync_phase_flags",
    "update_countdown",
    "refresh_from_dirty",
    "sync_follow",
    "sync_event_log",
  }
  local search_start = 1
  for _, name in ipairs(expected_order) do
    local matched = nil
    for i = search_start, #sequence do
      if sequence[i] == name then
        matched = i
        break
      end
    end
    assert(matched ~= nil, "missing expected tick order step: " .. tostring(name))
    search_start = matched + 1
  end
end

local function _test_action_button_timeout_auto_advances()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.players[1].auto = true
  state.auto_runner:set_enabled(false)
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_event_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 1, "action button timeout should advance turn")
end

local function _test_action_button_timeout_manual_wait_action_auto_advances()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  state.auto_runner:set_enabled(false)
  g.players[1].auto = false
  g.players[1].is_ai = false
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action"
  g.turn.pending_choice = nil

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_event_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    _with_timestamp_stub(function()
      local dt = (constants.action_timeout_seconds or 0) + 0.1
      gameplay_loop.tick(g, state, dt)
    end)
  end)

  assert(g.turn.phase ~= "wait_action", "manual wait_action timeout should leave wait_action")
  assert(g.last_turn and g.last_turn.total ~= nil, "manual wait_action timeout should auto roll")
end

local function _test_action_button_timeout_manual_player_does_not_advance()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  state.auto_runner:set_enabled(false)
  g.players[1].auto = false
  g.players[1].is_ai = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil
  state.action_button_active = true
  state.action_button_elapsed = (constants.action_timeout_seconds or 0) + 1
  state.action_button_player_id = g.players[2].id

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_event_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    _with_timestamp_stub(function()
      local dt = (constants.action_timeout_seconds or 0) + 0.1
      gameplay_loop.tick(g, state, dt)
    end)
  end)

  assert(advanced == 0, "manual player timeout should not advance turn")
  assert(state.action_button_active == false, "manual player should keep action timer disabled")
  assert(state.action_button_elapsed == 0, "manual player timeout should reset action timer")
  assert(state.action_button_player_id == nil, "manual player timeout reset should clear tracked actor")
end

local function _test_action_button_timeout_blocked_when_input_locked()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action_anim"
  g.turn.pending_choice = nil

  state.ui.input_blocked = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_event_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 15 },
  }, function()
    _with_timestamp_stub(function()
      local dt = (constants.action_timeout_seconds or 0) + 0.1
      gameplay_loop.tick(g, state, dt)
    end)
  end)

  assert(advanced == 0, "input locked should block action button timeout")
  assert(state.action_button_active == false, "input locked should disable action timer")
  assert(state.action_button_elapsed == 0, "input locked should reset action timer")
end

local function _test_action_button_timeout_blocked_when_popup_active()
  local g = _new_game()
  local state = _build_loop_state()
  g.ui_port = _build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  state.ui.popup_active = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = _build_test_ports({
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    play_move_anim = function() return 0 end,
    play_action_anim = function() return 0 end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    refresh_from_dirty = function()
      return false
    end,
    sync_event_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  _with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "popup active should block action button timeout")
  assert(state.action_button_active == false, "popup active should disable action timer")
  assert(state.action_button_elapsed == 0, "popup active should reset action timer")
end

local function _test_auto_runner_auto_advances_ai_player()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local auto_decision_delay = timing.auto_decision_delay_seconds or 0
  state.auto_runner.interval = auto_decision_delay
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local a1 = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.1, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a1 == nil, "should not trigger before reaching auto interval")
    local a2 = gameplay_loop.step_auto_runner(g, state, 0.1, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a2 and a2.type == "ui_button" and a2.id == "next", "ai player should auto dispatch next")
  end)
end

local function _test_auto_runner_human_turn_not_auto_advanced()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[1].id,
      current_player_auto = false,
    })
    assert(action == nil, "human turn should not auto dispatch next")
  end)
end

local function _test_gameplay_loop_ai_rounds_do_not_force_manual_timeout()
  local state = _build_loop_state()
  local g = {
    finished = false,
    players = {
      { id = 2, name = "Human2", is_ai = false, auto = false },
      { id = -2, name = "AI2", is_ai = true, auto = false },
      { id = -3, name = "AI3", is_ai = true, auto = false },
      { id = -4, name = "AI4", is_ai = true, auto = false },
    },
    turn = {
      current_player_index = 2,
      pending_choice = nil,
    },
  }
  local ports = _build_test_ports()
  local advanced = 0

  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 0.5 },
  }, function()
    local function _dispatch_next()
      advanced = advanced + 1
      local next_index = g.turn.current_player_index + 1
      if next_index > #g.players then
        next_index = 1
      end
      g.turn.current_player_index = next_index
      g.turn.pending_choice = nil
    end

    for _ = 1, 3 do
      turn_timer_policy.update_action_button_timer({
        game = g,
        state = state,
        dt = 0.6,
        ports = ports,
        dispatch_next = _dispatch_next,
      })
    end
    assert(g.turn.current_player_index == 1, "ai rounds should return control to manual player")
    local advanced_before = advanced

    state.action_button_active = true
    state.action_button_elapsed = 9
    state.action_button_player_id = g.players[4].id

    for _ = 1, 6 do
      turn_timer_policy.update_action_button_timer({
        game = g,
        state = state,
        dt = 0.6,
        ports = ports,
        dispatch_next = _dispatch_next,
      })
    end

    assert(g.turn.current_player_index == 1, "manual player should not be auto advanced by timeout")
    assert(advanced == advanced_before, "manual player timeout should not dispatch synthetic next")
    assert(state.action_button_active == false and state.action_button_elapsed == 0,
      "manual player timeout should reset action timer state")
    assert(state.action_button_player_id == nil, "manual player timeout reset should clear tracked actor")
  end)
end

local function _test_auto_runner_waits_for_auto_popup_delay()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local auto_player = g.players[2]
  local auto_decision_delay = timing.auto_decision_delay_seconds or 0
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1
  state.ui.popup_active = true
  state.ui.popup_owner_index = 2
  state.ui.popup_payload = {
    auto_close_seconds = auto_decision_delay + 3,
  }

  _with_timestamp_stub(function()
    ui_runtime.ui_modal_elapsed = auto_decision_delay - 0.1
    local blocked = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = auto_player.id,
      current_player_auto = true,
    })
    assert(blocked == nil, "auto popup should keep auto runner waiting before delay elapses")

    ui_runtime.ui_modal_elapsed = auto_decision_delay
    local action = gameplay_loop.step_auto_runner(g, state, auto_decision_delay, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = auto_player.id,
      current_player_auto = true,
    })
    assert(action and action.type == "ui_button" and action.id == "next",
      "auto popup should stop blocking once the shared delay is reached")
  end)
end

local function _test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local ai_player = g.players[2]
  local dispatched = nil
  local auto_decision_delay = timing.auto_decision_delay_seconds or 0
  local choice = {
    id = 701,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = ai_player.id,
    options = {
      { id = "buy_land", label = "购买地块" },
      { id = "skip", label = "跳过" },
    },
    allow_cancel = true,
    meta = {
      player_id = ai_player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 2
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
  g.dispatch_action = function(_, action)
    dispatched = action
    g.turn.pending_choice = nil
  end

  _with_timestamp_stub(function()
    local early = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.1, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(early == nil, "choice auto action should wait before looking decided")
    local action = gameplay_loop.step_auto_runner(g, state, 0.1, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(action and action.type == "choice_select", "auto runner should resolve pending choice without ui choice screen")
    assert(action.option_id == "buy_land", "auto runner should select buy_land for AI landing optional effect")
    assert(action.actor_role_id == ai_player.id, "auto runner should preserve AI owner role")
  end)

  assert(dispatched and dispatched.type == "choice_select", "auto runner should dispatch the auto-selected choice")
  assert(dispatched.option_id == "buy_land", "dispatched choice should still select buy_land")
end

local function _test_auto_runner_resets_timer_when_wait_kind_changes()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  local ai_player = g.players[2]
  local dispatched = nil
  local auto_decision_delay = timing.auto_decision_delay_seconds or 0
  local choice = {
    id = 704,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = ai_player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = {
      player_id = ai_player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  state.auto_runner.interval = auto_decision_delay
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.dispatch_action = function(_, action)
    dispatched = action
    g.turn.pending_choice = nil
  end

  _with_timestamp_stub(function()
    local next_action = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(next_action == nil, "next timer should not fire before short delay")

    g.turn.phase = "wait_choice"
    g.turn.pending_choice = choice
    runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })

    local early_choice = gameplay_loop.step_auto_runner(g, state, auto_decision_delay - 0.2, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(early_choice == nil, "choice timer should reset when switching from next to wait_choice")

    local final_choice = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game = g,
      state = state,
      pending_choice = choice,
      choice_active = false,
      market_active = false,
      popup_active = false,
      current_player_index = g.turn.current_player_index,
      current_player_id = ai_player.id,
      current_player_auto = true,
    })
    assert(final_choice and final_choice.type == "choice_select", "choice timer should fire after a fresh full wait")
  end)
  assert(dispatched and dispatched.type == "choice_select", "final choice should still dispatch after reset")
end

local function _test_auto_runner_not_advanced_when_input_blocked()
  local g = _new_game()
  g.ui_port = _build_ui_port()
  local state = _build_loop_state()
  state.ui.input_blocked = true
  g.turn.current_player_index = 2
  g.turn.phase = "wait_action_anim"
  g.turn.turn_count = 1

  _with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(action == nil, "blocked phase should not auto dispatch next")
  end)
end

local function _test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[2]
  local dispatched = nil
  local choice = {
    id = 702,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 2
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })

  tick_choice_timeout.step(g, state, (constants.action_timeout_seconds or 0) + 0.1, {
    on_pending_choice = function() end,
    is_choice_active = function()
      return false
    end,
    build_action = function()
      return {
        type = "choice_select",
        choice_id = choice.id,
        option_id = "buy_land",
      }
    end,
    dispatch_action_with_close_choice = function(_, _, action)
      dispatched = action
    end,
  })

  assert(dispatched and dispatched.type == "choice_select", "timeout should still dispatch choice action without ui choice screen")
  assert(dispatched.actor_role_id == player.id, "timeout-dispatched choice should inherit owner role id")
  assert(runtime_state.get_pending_choice_elapsed(state) == 0, "timeout should reset pending choice elapsed after dispatch")
end

local function _test_tick_choice_timeout_manual_player_keeps_waiting()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[1]
  local dispatched = nil
  local choice = {
    id = 721,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    allow_cancel = true,
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 1
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })

  tick_choice_timeout.step(g, state, (constants.action_timeout_seconds or 0) + 0.1, {
    on_pending_choice = function() end,
    is_choice_active = function()
      return false
    end,
    build_action = function(game_ctx, state_ctx, active_choice, payload)
      return choice_auto_policy.decide(game_ctx, state_ctx, active_choice, payload)
    end,
    dispatch_action_with_close_choice = function(_, _, action)
      dispatched = action
    end,
  })

  assert(dispatched ~= nil, "manual player timeout should dispatch optional completion action")
  assert(dispatched.type == "complete_optional_action_phase",
    "manual player timeout should dispatch optional completion")
  assert(dispatched.choice_id == nil, "optional completion action should not expose choice_id")
  assert(dispatched.actor_role_id == player.id, "optional completion should carry the choice owner actor")
end

local function _test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[2]
  local choice = {
    id = 703,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 2
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, {
    choice_id = choice.id,
    elapsed_seconds = 1,
  })
  state.ui.choice_active = false
  state.ui.market_active = false

  tick_ui_sync.update_countdown(g, state)

  assert(g.turn.countdown_active == true, "countdown should stay active for runtime pending choice without ui choice screen")
  assert(g.turn.countdown_seconds == (constants.action_timeout_seconds or 0) - 1,
    "countdown should use runtime pending choice elapsed seconds")
end

local function _test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout()
  local g = _new_game()
  local state = _build_loop_state()
  local player = g.players[1]
  local choice = {
    id = 722,
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    owner_role_id = player.id,
    options = { { id = "buy_land", label = "购买地块" } },
    meta = {
      player_id = player.id,
      tile_id = 1,
      effect_ids = { "buy_land" },
    },
  }
  g.turn.current_player_index = 1
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, {
    choice_id = choice.id,
    elapsed_seconds = 1,
  })
  state.ui.choice_active = false
  state.ui.market_active = false

  tick_ui_sync.update_countdown(g, state)

  assert(g.turn.countdown_active == true, "manual pending choice should expose countdown")
  assert(g.turn.countdown_seconds > 0, "manual pending choice countdown should be visible")
end

local function _test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice()
  local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
  local warned = {}

  local function _run_case(choice, state, current_player_index)
    local g = _new_game()
    g.turn.current_player_index = current_player_index or 1
    g.turn.phase = "wait_choice"
    g.turn.pending_choice = choice
    runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
    tick_choice_timeout.step(g, state, 0.1, {
      on_pending_choice = function() end,
      is_choice_active = function()
        return false
      end,
      resolve_choice_ui_state = function(game_ctx, state_ctx, active_choice)
        return choice_ui_state.resolve_gate_state(game_ctx, state_ctx, active_choice)
      end,
      build_action = function()
        return nil
      end,
      dispatch_action_with_close_choice = function() end,
    })
  end

  support.with_patches({
    { target = logger, key = "warn", value = function(...)
      warned[#warned + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    local base_inline_state = _build_loop_state()
    runtime_state.set_ui_model(base_inline_state, { current_player_id = 1 })
    _run_case({
      id = 810,
      kind = "item_phase_choice",
      route_key = "base_inline",
      owner_role_id = 1,
      uses_item_slots = true,
      options = { { id = 2001, label = "路障卡" } },
      meta = { player_id = 1, phase = "pre_action" },
    }, base_inline_state, 1)

    local market_state = _build_loop_state()
    market_state.ui.market_active = true
    runtime_state.set_ui_model(market_state, { current_player_id = 1 })
    _run_case({
      id = 811,
      kind = "market_buy",
      route_key = "market",
      owner_role_id = 1,
      options = { { id = 1, label = "A" } },
      meta = { player_id = 1 },
    }, market_state, 1)

    local ai_state = _build_loop_state()
    runtime_state.set_ui_model(ai_state, { current_player_id = 2 })
    _run_case({
      id = 812,
      kind = "landing_optional_effect",
      route_key = "secondary_confirm",
      owner_role_id = 2,
      options = { { id = "buy_land", label = "购买地块" } },
      meta = { player_id = 2, tile_id = 1, effect_ids = { "buy_land" } },
    }, ai_state, 2)
  end)

  assert(#warned == 0, "non-modal or non-local pending choices should not log missing-ui warning")
end

local function _test_tick_choice_timeout_warning_keeps_local_modal_choice()
  local choice_ui_state = require("src.ui.ports.ui_sync")._choice_state
  local warned = {}
  local g = _new_game()
  local state = _build_loop_state()
  local choice = {
    id = 813,
    kind = "remote_dice_value",
    route_key = "remote",
    owner_role_id = 1,
    options = { { id = 1, label = "1" } },
    meta = { player_id = 1, item_id = item_ids.remote_dice, dice_count = 1 },
  }
  g.turn.current_player_index = 1
  g.turn.phase = "wait_choice"
  g.turn.pending_choice = choice
  runtime_state.set_pending_choice(state, choice, { choice_id = choice.id, elapsed_seconds = 0 })
  runtime_state.set_ui_model(state, { current_player_id = 1 })
  runtime_state.set_local_actor_role_id(state, 1)

  support.with_patches({
    { target = logger, key = "warn", value = function(...)
      warned[#warned + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    tick_choice_timeout.step(g, state, 0.1, {
      on_pending_choice = function() end,
      is_choice_active = function()
        return false
      end,
      resolve_choice_ui_state = function(game_ctx, state_ctx, active_choice)
        return choice_ui_state.resolve_gate_state(game_ctx, state_ctx, active_choice)
      end,
      build_action = function()
        return nil
      end,
      dispatch_action_with_close_choice = function() end,
    })
  end)

  assert(#warned == 1, "local modal choice should still log missing-ui warning")
  assert(string.find(warned[1], "runtime pending choice active without ui.choice_active", 1, true) ~= nil,
    "local modal warning should keep original message")
end

  return {
    _test_tick_headless_ports_cover_anim_phases = _test_tick_headless_ports_cover_anim_phases,
    _test_action_button_timeout_auto_advances = _test_action_button_timeout_auto_advances,
    _test_action_button_timeout_manual_wait_action_auto_advances = _test_action_button_timeout_manual_wait_action_auto_advances,
    _test_action_button_timeout_manual_player_does_not_advance = _test_action_button_timeout_manual_player_does_not_advance,
    _test_action_button_timeout_blocked_when_input_locked = _test_action_button_timeout_blocked_when_input_locked,
    _test_action_button_timeout_blocked_when_popup_active = _test_action_button_timeout_blocked_when_popup_active,
    _test_auto_runner_auto_advances_ai_player = _test_auto_runner_auto_advances_ai_player,
    _test_auto_runner_human_turn_not_auto_advanced = _test_auto_runner_human_turn_not_auto_advanced,
    _test_gameplay_loop_ai_rounds_do_not_force_manual_timeout = _test_gameplay_loop_ai_rounds_do_not_force_manual_timeout,
    _test_auto_runner_waits_for_auto_popup_delay = _test_auto_runner_waits_for_auto_popup_delay,
    _test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen = _test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen,
    _test_auto_runner_resets_timer_when_wait_kind_changes = _test_auto_runner_resets_timer_when_wait_kind_changes,
    _test_auto_runner_not_advanced_when_input_blocked = _test_auto_runner_not_advanced_when_input_blocked,
    _test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen = _test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen,
    _test_tick_choice_timeout_manual_player_keeps_waiting = _test_tick_choice_timeout_manual_player_keeps_waiting,
    _test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen = _test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen,
    _test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout = _test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout,
    _test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice = _test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice,
    _test_tick_choice_timeout_warning_keeps_local_modal_choice = _test_tick_choice_timeout_warning_keeps_local_modal_choice,
  }
end

return { make_cases = make_cases }
