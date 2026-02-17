local support = require("support.regression_support")
local context_helpers = require("support.regression.runtime_context_helpers")
local loop_builder = require("support.regression.loop_state_builder")

local new_game = support.new_game
local gameplay_loop = support.gameplay_loop
local tick_timeout = support.tick_timeout
local constants = support.constants
local turn_flow = support.turn_flow
local with_turn_flow = support.with_turn_flow

local function test_tick_headless_ports_cover_anim_phases()
  local g = new_game()
  g.update = nil
  local state = loop_builder.build_loop_state()
  state.ui = nil
  state.wait_move_anim = true
  state.wait_action_anim = true
  local dispatched = {}
  g.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end

  local calls = {
    move_anim = 0,
    action_anim = 0,
    countdown = 0,
    refresh = 0,
  }

  state.gameplay_loop_ports = loop_builder.build_test_ports({
    play_move_anim = function(_, anim_ctx)
      calls.move_anim = calls.move_anim + 1
      assert(anim_ctx and anim_ctx.seq == 101, "move anim ctx should be injected")
      return 0
    end,
    play_action_anim = function(_, anim_ctx)
      calls.action_anim = calls.action_anim + 1
      assert(anim_ctx and anim_ctx.seq == 201, "action anim ctx should be injected")
      return 0
    end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function()
      calls.countdown = calls.countdown + 1
    end,
    refresh_from_dirty = function()
      calls.refresh = calls.refresh + 1
      return false
    end,
    sync_debug_log = function() end,
    log_status = function() end,
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    apply_input_lock = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  g.turn.phase = "wait_move_anim"
  g.turn.move_anim = { seq = 101 }
  gameplay_loop.tick(g, state, 0.1)
  assert(calls.move_anim == 1, "headless move anim should use injected port")
  assert(dispatched[1] and dispatched[1].type == "move_anim_done", "move anim should dispatch move_anim_done")
  assert(dispatched[1] and dispatched[1].seq == 101, "move anim seq should be forwarded")

  g.turn.phase = "wait_action_anim"
  g.turn.action_anim = { seq = 201 }
  gameplay_loop.tick(g, state, 0.1)
  assert(calls.action_anim == 1, "headless action anim should use injected port")
  assert(dispatched[2] and dispatched[2].type == "action_anim_done", "action anim should dispatch action_anim_done")
  assert(dispatched[2] and dispatched[2].seq == 201, "action anim seq should be forwarded")

  assert(calls.countdown >= 2, "countdown should still step under custom ports")
  assert(calls.refresh >= 2, "refresh_from_dirty should still be called under custom ports")
end

local function test_action_button_timeout_auto_advances()
  local g = new_game()
  local state = loop_builder.build_loop_state()
  g.ui_port = support.build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = loop_builder.build_test_ports({
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
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  context_helpers.with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 1, "action button timeout should advance turn")
end

local function test_action_button_timeout_blocked_when_input_locked()
  local g = new_game()
  g.update = nil
  local state = loop_builder.build_loop_state()
  g.ui_port = support.build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "wait_action_anim"
  g.turn.pending_choice = nil

  state.ui.input_blocked = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = loop_builder.build_test_ports({
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
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  context_helpers.with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "input locked should block action button timeout")
  assert(state.action_button_active == false, "input locked should disable action timer")
  assert(state.action_button_elapsed == 0, "input locked should reset action timer")
end

local function test_action_button_timeout_blocked_when_popup_active()
  local g = new_game()
  local state = loop_builder.build_loop_state()
  g.ui_port = support.build_ui_port()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.pending_choice = nil

  state.ui.popup_active = true

  local advanced = 0
  g.advance_turn = function()
    advanced = advanced + 1
  end

  state.gameplay_loop_ports = loop_builder.build_test_ports({
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
    sync_debug_log = function() end,
    log_status = function() end,
    build_model = function()
      return { choice = nil, market = nil }
    end,
  })

  context_helpers.with_timestamp_stub(function()
    local dt = (constants.action_timeout_seconds or 0) + 0.1
    gameplay_loop.tick(g, state, dt)
  end)

  assert(advanced == 0, "popup active should block action button timeout")
  assert(state.action_button_active == false, "popup active should disable action timer")
  assert(state.action_button_elapsed == 0, "popup active should reset action timer")
end

local function test_auto_runner_auto_advances_ai_player()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  state.auto_runner.interval = 0.4
  g.turn.current_player_index = 2
  g.turn.phase = "start"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local a1 = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a1 == nil, "should not trigger before reaching auto interval")
    local a2 = gameplay_loop.step_auto_runner(g, state, 0.2, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(a2 and a2.type == "ui_button" and a2.id == "next", "ai player should auto dispatch next")
  end)
end

local function test_auto_runner_human_turn_not_auto_advanced()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[1].id,
      current_player_auto = false,
    })
    assert(action == nil, "human turn should not auto dispatch next")
  end)
end

local function test_auto_runner_not_advanced_when_input_blocked()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  state.ui.input_blocked = true
  g.turn.current_player_index = 2
  g.turn.phase = "wait_action_anim"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local action = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_id = g.players[2].id,
      current_player_auto = true,
    })
    assert(action == nil, "blocked phase should not auto dispatch next")
  end)
end

local function test_turn_prompt_initialized_for_first_player()
  local g = new_game()
  local current_player = g:current_player()

  assert((g.turn.turn_start_prompt_seq or 0) == 1, "first turn should initialize prompt seq")
  assert(g.turn.turn_start_prompt_player_id == current_player.id,
    "first turn prompt target should be current player")
end

local function test_turn_prompt_emitted_on_next_player_switch()
  local g = new_game()
  with_turn_flow(g)
  local before_seq = g.turn.turn_start_prompt_seq or 0
  local before_index = g.turn.current_player_index
  local expected_next_index = before_index % #g.players + 1
  local expected_player = g.players[expected_next_index]

  g.turn_flow:next_player()

  assert(g.turn.current_player_index == expected_next_index, "next_player should switch player index")
  assert((g.turn.turn_start_prompt_seq or 0) == before_seq + 1,
    "next_player should emit one new prompt seq")
  assert(g.turn.turn_start_prompt_player_id == expected_player.id,
    "next_player prompt target should be switched player")
end

local function test_auto_runner_depends_on_current_player_auto()
  local g = new_game()
  g.ui_port = support.build_ui_port()
  local state = loop_builder.build_loop_state()
  g.players[1].auto = true
  g.players[2].auto = false
  g.turn.current_player_index = 1
  g.turn.phase = "start"
  g.turn.turn_count = 1

  context_helpers.with_timestamp_stub(function()
    local action1 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = true,
    })
    assert(action1 and action1.type == "ui_button" and action1.id == "next",
      "current player auto should dispatch next")

    state.next_turn_locked = false
    g.turn.current_player_index = 2
    local action2 = gameplay_loop.step_auto_runner(g, state, 1.0, {
      game_finished = g.finished,
      current_player_index = g.turn.current_player_index,
      current_player_auto = false,
    })
    assert(action2 == nil, "current player auto=false should not dispatch")
  end)
end


return {
  test_tick_headless_ports_cover_anim_phases,
  test_action_button_timeout_auto_advances,
  test_action_button_timeout_blocked_when_input_locked,
  test_action_button_timeout_blocked_when_popup_active,
  test_auto_runner_auto_advances_ai_player,
  test_auto_runner_human_turn_not_auto_advanced,
  test_auto_runner_not_advanced_when_input_blocked,
  test_auto_runner_depends_on_current_player_auto,
  test_turn_prompt_initialized_for_first_player,
  test_turn_prompt_emitted_on_next_player_switch,
}
