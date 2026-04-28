local loop_runtime = require("src.turn.loop.runtime")
local runtime_state = require("src.state.runtime_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_state()
  return {}
end

-- is_phase_input_blocked

local function test_is_phase_input_blocked_wait_move_anim()
  _assert_eq(loop_runtime.is_phase_input_blocked("wait_move_anim"), true, "wait_move_anim should be blocked")
end

local function test_is_phase_input_blocked_wait_action_anim()
  _assert_eq(loop_runtime.is_phase_input_blocked("wait_action_anim"), true, "wait_action_anim should be blocked")
end

local function test_is_phase_input_blocked_wait_landing_visual()
  _assert_eq(loop_runtime.is_phase_input_blocked("wait_landing_visual"), true, "wait_landing_visual should be blocked")
end

local function test_is_phase_input_blocked_detained_wait()
  _assert_eq(loop_runtime.is_phase_input_blocked("detained_wait"), true, "detained_wait should be blocked")
end

local function test_is_phase_input_blocked_inter_turn_wait()
  _assert_eq(loop_runtime.is_phase_input_blocked("inter_turn_wait"), true, "inter_turn_wait should be blocked")
end

local function test_is_phase_input_blocked_other_returns_false()
  _assert_eq(loop_runtime.is_phase_input_blocked("pre_move"), false, "pre_move should not be blocked")
  _assert_eq(loop_runtime.is_phase_input_blocked("move"), false, "move should not be blocked")
  _assert_eq(loop_runtime.is_phase_input_blocked(nil), false, "nil should not be blocked")
end

-- sync_input_blocked

local function test_sync_input_blocked_no_ports_returns_false()
  local state = _make_state()
  local result = loop_runtime.sync_input_blocked(state, "wait_move_anim", nil)
  _assert_eq(result, false, "nil ports should return false")
end

local function test_sync_input_blocked_no_ui_sync_returns_false()
  local state = _make_state()
  local result = loop_runtime.sync_input_blocked(state, "wait_move_anim", { other = true })
  _assert_eq(result, false, "ports without ui_sync should return false")
end

local function test_sync_input_blocked_missing_get_ui_state_returns_false()
  local state = _make_state()
  local ports = { ui_sync = { set_input_blocked = function() end } }
  local result = loop_runtime.sync_input_blocked(state, "pre_move", ports)
  _assert_eq(result, false, "missing get_ui_state should return false")
end

local function test_sync_input_blocked_nil_ui_returns_false()
  local state = _make_state()
  local ports = {
    ui_sync = {
      get_ui_state = function() return nil end,
      set_input_blocked = function() return true end,
    },
  }
  local result = loop_runtime.sync_input_blocked(state, "pre_move", ports)
  _assert_eq(result, false, "nil ui_state should return false")
end

local function test_sync_input_blocked_set_returns_false_propagates()
  local state = _make_state()
  local ports = {
    ui_sync = {
      get_ui_state = function() return { some = "ui" } end,
      set_input_blocked = function() return false end,
    },
  }
  local result = loop_runtime.sync_input_blocked(state, "wait_move_anim", ports)
  _assert_eq(result, false, "set_input_blocked returning false should propagate")
end

local function test_sync_input_blocked_blocked_phase_passes_true()
  local state = _make_state()
  local received_blocked
  local ports = {
    ui_sync = {
      get_ui_state = function() return { ui = true } end,
      set_input_blocked = function(_, blocked)
        received_blocked = blocked
        return true
      end,
    },
  }
  local result = loop_runtime.sync_input_blocked(state, "wait_action_anim", ports)
  _assert_eq(result, true, "blocked phase with set returning true should return true")
  _assert_eq(received_blocked, true, "set_input_blocked should receive true for blocked phase")
end

local function test_sync_input_blocked_unblocked_phase_passes_false()
  local state = _make_state()
  local received_blocked
  local ports = {
    ui_sync = {
      get_ui_state = function() return { ui = true } end,
      set_input_blocked = function(_, blocked)
        received_blocked = blocked
        return true
      end,
    },
  }
  loop_runtime.sync_input_blocked(state, "pre_move", ports)
  _assert_eq(received_blocked, false, "set_input_blocked should receive false for non-blocked phase")
end

-- sync_phase_flags

local function test_sync_phase_flags_sets_board_last_phase()
  local state = _make_state()
  loop_runtime.sync_phase_flags(state, "pre_move")
  local board_runtime = runtime_state.ensure_board_runtime(state)
  _assert_eq(board_runtime.board_last_phase, "pre_move", "board_last_phase should be set")
end

local function test_sync_phase_flags_transitions_from_wait_move_anim_sets_board_sync_pending()
  local state = _make_state()
  loop_runtime.sync_phase_flags(state, "wait_move_anim")
  loop_runtime.sync_phase_flags(state, "pre_move")
  local board_runtime = runtime_state.ensure_board_runtime(state)
  _assert_eq(board_runtime.board_sync_pending, true, "leaving wait_move_anim should set board_sync_pending")
end

local function test_sync_phase_flags_same_wait_move_anim_no_sync_pending()
  local state = _make_state()
  loop_runtime.sync_phase_flags(state, "wait_move_anim")
  loop_runtime.sync_phase_flags(state, "wait_move_anim")
  local board_runtime = runtime_state.ensure_board_runtime(state)
  assert(not board_runtime.board_sync_pending, "staying in wait_move_anim should not set board_sync_pending")
end

local function test_sync_phase_flags_unlocks_next_turn_lock_on_phase_change()
  local state = _make_state()
  loop_runtime.sync_phase_flags(state, "pre_move")
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  turn_runtime.next_turn_locked = true
  turn_runtime.next_turn_lock_phase = "pre_move"
  loop_runtime.sync_phase_flags(state, "move")
  _assert_eq(turn_runtime.next_turn_locked, false, "changing phase should unlock next_turn_locked")
end

-- build_board_scene_port

local function test_build_board_scene_port_returns_table()
  local state = _make_state()
  local port = loop_runtime.build_board_scene_port(state)
  assert(type(port) == "table", "should return a port table")
  assert(type(port.get_board_scene) == "function", "should have get_board_scene")
end

local function test_build_board_scene_port_get_board_scene_returns_state_board_scene()
  local state = _make_state()
  state.board_scene = { some_scene = true }
  local port = loop_runtime.build_board_scene_port(state)
  _assert_eq(port.get_board_scene(), state.board_scene, "get_board_scene should return state.board_scene")
end

local function test_build_board_scene_port_cached_on_second_call()
  local state = _make_state()
  local port1 = loop_runtime.build_board_scene_port(state)
  local port2 = loop_runtime.build_board_scene_port(state)
  _assert_eq(port1, port2, "second call should return cached port")
end

-- build_popup_port

local function test_build_popup_port_returns_table_with_push_popup()
  local state = _make_state()
  local port = loop_runtime.build_popup_port(state)
  assert(type(port) == "table", "should return a port table")
  assert(type(port.push_popup) == "function", "should have push_popup function")
end

local function test_build_popup_port_push_popup_returns_false_when_no_push_popup_fn()
  local state = _make_state()
  state.push_popup = nil
  local port = loop_runtime.build_popup_port(state)
  local result = port.push_popup(nil, {}, {})
  _assert_eq(result, false, "push_popup should return false when state has no push_popup function")
end

local function test_build_popup_port_cached_on_second_call()
  local state = _make_state()
  local port1 = loop_runtime.build_popup_port(state)
  local port2 = loop_runtime.build_popup_port(state)
  _assert_eq(port1, port2, "second call should return cached port")
end

-- build_tip_output_port

local function test_build_tip_output_port_enqueue_returns_false_when_no_show_tip()
  local state = _make_state()
  local port = loop_runtime.build_tip_output_port(state)
  local result = port.enqueue(nil, { text = "hi" })
  _assert_eq(result, false, "enqueue should return false when state has no show_tip function")
end

local function test_build_tip_output_port_enqueue_calls_show_tip()
  local state = _make_state()
  local called_with
  state.show_tip = function(_, intent)
    called_with = intent
    return true
  end
  local port = loop_runtime.build_tip_output_port(state)
  local result = port.enqueue(nil, { text = "hello" })
  _assert_eq(result, true, "enqueue should return true when show_tip returns true")
  _assert_eq(called_with.text, "hello", "show_tip should receive the intent")
end

local function test_build_tip_output_port_cached_on_second_call()
  local state = _make_state()
  local port1 = loop_runtime.build_tip_output_port(state)
  local port2 = loop_runtime.build_tip_output_port(state)
  _assert_eq(port1, port2, "second call should return cached port")
end

-- build_tile_feedback_port

local function test_build_tile_feedback_port_returns_table()
  local state = _make_state()
  local port = loop_runtime.build_tile_feedback_port(state)
  assert(type(port) == "table", "should return a port table")
  assert(type(port.on_tile_upgraded) == "function", "should have on_tile_upgraded")
end

local function test_build_tile_feedback_port_no_game_returns_false()
  local state = _make_state()
  state.game = nil
  local port = loop_runtime.build_tile_feedback_port(state)
  local result = port.on_tile_upgraded(nil, 1, 2)
  _assert_eq(result, false, "no game should return false")
end

local function test_build_tile_feedback_port_cached_on_second_call()
  local state = _make_state()
  local port1 = loop_runtime.build_tile_feedback_port(state)
  local port2 = loop_runtime.build_tile_feedback_port(state)
  _assert_eq(port1, port2, "second call should return cached port")
end

-- build_anim_gate_port

local function test_build_anim_gate_port_returns_table_with_flags()
  local state = _make_state()
  state.wait_move_anim = true
  state.wait_action_anim = true
  local port = loop_runtime.build_anim_gate_port(state)
  _assert_eq(port.wait_move_anim, true, "wait_move_anim should reflect state")
  _assert_eq(port.wait_action_anim, true, "wait_action_anim should reflect state")
end

local function test_build_anim_gate_port_flags_false_when_not_set()
  local state = _make_state()
  local port = loop_runtime.build_anim_gate_port(state)
  _assert_eq(port.wait_move_anim, false, "wait_move_anim should be false when not set")
  _assert_eq(port.wait_action_anim, false, "wait_action_anim should be false when not set")
end

local function test_build_anim_gate_port_cached_on_second_call()
  local state = _make_state()
  local port1 = loop_runtime.build_anim_gate_port(state)
  local port2 = loop_runtime.build_anim_gate_port(state)
  _assert_eq(port1, port2, "second call should return cached port")
end

-- build_board_visual_feedback_port

local function test_build_board_visual_feedback_port_returns_table()
  local state = _make_state()
  local port = loop_runtime.build_board_visual_feedback_port(state)
  assert(type(port) == "table", "should return a port table")
  assert(type(port.sync_many) == "function", "should have sync_many")
end

local function test_build_board_visual_feedback_port_cached_on_second_call()
  local state = _make_state()
  local port1 = loop_runtime.build_board_visual_feedback_port(state)
  local port2 = loop_runtime.build_board_visual_feedback_port(state)
  _assert_eq(port1, port2, "second call should return cached port")
end

local function test_build_board_visual_feedback_port_sync_many_no_callback_returns_false()
  local state = _make_state()
  state.on_board_visual_sync = nil
  local port = loop_runtime.build_board_visual_feedback_port(state)
  local result = port.sync_many({}, nil)
  _assert_eq(result, false, "sync_many with no callback should return false")
end

return {
  name = "domain loop runtime coverage",
  tests = {
    { name = "is_phase_input_blocked wait_move_anim", run = test_is_phase_input_blocked_wait_move_anim },
    { name = "is_phase_input_blocked wait_action_anim", run = test_is_phase_input_blocked_wait_action_anim },
    { name = "is_phase_input_blocked wait_landing_visual", run = test_is_phase_input_blocked_wait_landing_visual },
    { name = "is_phase_input_blocked detained_wait", run = test_is_phase_input_blocked_detained_wait },
    { name = "is_phase_input_blocked inter_turn_wait", run = test_is_phase_input_blocked_inter_turn_wait },
    { name = "is_phase_input_blocked other returns false", run = test_is_phase_input_blocked_other_returns_false },
    { name = "sync_input_blocked no ports returns false", run = test_sync_input_blocked_no_ports_returns_false },
    { name = "sync_input_blocked no ui_sync returns false", run = test_sync_input_blocked_no_ui_sync_returns_false },
    { name = "sync_input_blocked missing get_ui_state returns false", run = test_sync_input_blocked_missing_get_ui_state_returns_false },
    { name = "sync_input_blocked nil ui returns false", run = test_sync_input_blocked_nil_ui_returns_false },
    { name = "sync_input_blocked set_returns_false propagates", run = test_sync_input_blocked_set_returns_false_propagates },
    { name = "sync_input_blocked blocked phase passes true", run = test_sync_input_blocked_blocked_phase_passes_true },
    { name = "sync_input_blocked unblocked phase passes false", run = test_sync_input_blocked_unblocked_phase_passes_false },
    { name = "sync_phase_flags sets board_last_phase", run = test_sync_phase_flags_sets_board_last_phase },
    { name = "sync_phase_flags transitions from wait_move_anim sets board_sync_pending", run = test_sync_phase_flags_transitions_from_wait_move_anim_sets_board_sync_pending },
    { name = "sync_phase_flags same wait_move_anim no sync_pending", run = test_sync_phase_flags_same_wait_move_anim_no_sync_pending },
    { name = "sync_phase_flags unlocks next_turn_lock on phase change", run = test_sync_phase_flags_unlocks_next_turn_lock_on_phase_change },
    { name = "build_board_scene_port returns table", run = test_build_board_scene_port_returns_table },
    { name = "build_board_scene_port get_board_scene returns state.board_scene", run = test_build_board_scene_port_get_board_scene_returns_state_board_scene },
    { name = "build_board_scene_port cached on second call", run = test_build_board_scene_port_cached_on_second_call },
    { name = "build_popup_port returns table with push_popup", run = test_build_popup_port_returns_table_with_push_popup },
    { name = "build_popup_port push_popup returns false when no push_popup fn", run = test_build_popup_port_push_popup_returns_false_when_no_push_popup_fn },
    { name = "build_popup_port cached on second call", run = test_build_popup_port_cached_on_second_call },
    { name = "build_tip_output_port enqueue returns false when no show_tip", run = test_build_tip_output_port_enqueue_returns_false_when_no_show_tip },
    { name = "build_tip_output_port enqueue calls show_tip", run = test_build_tip_output_port_enqueue_calls_show_tip },
    { name = "build_tip_output_port cached on second call", run = test_build_tip_output_port_cached_on_second_call },
    { name = "build_tile_feedback_port returns table", run = test_build_tile_feedback_port_returns_table },
    { name = "build_tile_feedback_port no game returns false", run = test_build_tile_feedback_port_no_game_returns_false },
    { name = "build_tile_feedback_port cached on second call", run = test_build_tile_feedback_port_cached_on_second_call },
    { name = "build_anim_gate_port returns table with flags", run = test_build_anim_gate_port_returns_table_with_flags },
    { name = "build_anim_gate_port flags false when not set", run = test_build_anim_gate_port_flags_false_when_not_set },
    { name = "build_anim_gate_port cached on second call", run = test_build_anim_gate_port_cached_on_second_call },
    { name = "build_board_visual_feedback_port returns table", run = test_build_board_visual_feedback_port_returns_table },
    { name = "build_board_visual_feedback_port cached on second call", run = test_build_board_visual_feedback_port_cached_on_second_call },
    { name = "build_board_visual_feedback_port sync_many no callback returns false", run = test_build_board_visual_feedback_port_sync_many_no_callback_returns_false },
  },
}
