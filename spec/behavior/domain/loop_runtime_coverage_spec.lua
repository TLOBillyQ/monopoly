local loop_runtime = require("src.turn.loop.runtime")
local runtime_state = require("src.state.runtime")
local tip_queue = require("src.foundation.coordination.tip_queue")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_state()
  return {}
end

-- is_phase_input_blocked







-- sync_input_blocked








-- sync_phase_flags





-- build_board_scene_port




-- build_popup_port




-- build_tip_output_port




-- build_tile_feedback_port




-- build_anim_gate_port




-- build_board_visual_feedback_port

describe("domain loop runtime coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("is_phase_input_blocked wait_move_anim", function()
    _assert_eq(loop_runtime.is_phase_input_blocked("wait_move_anim"), true, "wait_move_anim should be blocked")
  end)

  it("is_phase_input_blocked wait_action_anim", function()
    _assert_eq(loop_runtime.is_phase_input_blocked("wait_action_anim"), true, "wait_action_anim should be blocked")
  end)

  it("is_phase_input_blocked wait_landing_visual", function()
    _assert_eq(loop_runtime.is_phase_input_blocked("wait_landing_visual"), true, "wait_landing_visual should be blocked")
  end)

  it("is_phase_input_blocked detained_wait", function()
    _assert_eq(loop_runtime.is_phase_input_blocked("detained_wait"), true, "detained_wait should be blocked")
  end)

  it("is_phase_input_blocked inter_turn_wait", function()
    _assert_eq(loop_runtime.is_phase_input_blocked("inter_turn_wait"), true, "inter_turn_wait should be blocked")
  end)

  it("is_phase_input_blocked other returns false", function()
    _assert_eq(loop_runtime.is_phase_input_blocked("pre_move"), false, "pre_move should not be blocked")
    _assert_eq(loop_runtime.is_phase_input_blocked("move"), false, "move should not be blocked")
    _assert_eq(loop_runtime.is_phase_input_blocked(nil), false, "nil should not be blocked")
  end)

  it("sync_input_blocked no ports returns false", function()
    local state = _make_state()
    local result = loop_runtime.sync_input_blocked(state, "wait_move_anim", nil)
    _assert_eq(result, false, "nil ports should return false")
  end)

  it("sync_input_blocked no ui_sync returns false", function()
    local state = _make_state()
    local result = loop_runtime.sync_input_blocked(state, "wait_move_anim", { other = true })
    _assert_eq(result, false, "ports without ui_sync should return false")
  end)

  it("sync_input_blocked missing get_ui_state returns false", function()
    local state = _make_state()
    local ports = { ui_sync = { set_input_blocked = function() end } }
    local result = loop_runtime.sync_input_blocked(state, "pre_move", ports)
    _assert_eq(result, false, "missing get_ui_state should return false")
  end)

  it("sync_input_blocked nil ui returns false", function()
    local state = _make_state()
    local ports = {
      ui_sync = {
        get_ui_state = function() return nil end,
        set_input_blocked = function() return true end,
      },
    }
    local result = loop_runtime.sync_input_blocked(state, "pre_move", ports)
    _assert_eq(result, false, "nil ui_state should return false")
  end)

  it("sync_input_blocked set_returns_false propagates", function()
    local state = _make_state()
    local ports = {
      ui_sync = {
        get_ui_state = function() return { some = "ui" } end,
        set_input_blocked = function() return false end,
      },
    }
    local result = loop_runtime.sync_input_blocked(state, "wait_move_anim", ports)
    _assert_eq(result, false, "set_input_blocked returning false should propagate")
  end)

  it("sync_input_blocked blocked phase passes true", function()
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
  end)

  it("sync_input_blocked unblocked phase passes false", function()
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
  end)

  it("sync_phase_flags sets board_last_phase", function()
    local state = _make_state()
    loop_runtime.sync_phase_flags(state, "pre_move")
    local board_runtime = runtime_state.ensure_board_runtime(state)
    _assert_eq(board_runtime.board_last_phase, "pre_move", "board_last_phase should be set")
  end)

  it("sync_phase_flags transitions from wait_move_anim sets board_sync_pending", function()
    local state = _make_state()
    loop_runtime.sync_phase_flags(state, "wait_move_anim")
    loop_runtime.sync_phase_flags(state, "pre_move")
    local board_runtime = runtime_state.ensure_board_runtime(state)
    _assert_eq(board_runtime.board_sync_pending, true, "leaving wait_move_anim should set board_sync_pending")
  end)

  it("sync_phase_flags same wait_move_anim no sync_pending", function()
    local state = _make_state()
    loop_runtime.sync_phase_flags(state, "wait_move_anim")
    loop_runtime.sync_phase_flags(state, "wait_move_anim")
    local board_runtime = runtime_state.ensure_board_runtime(state)
    assert(not board_runtime.board_sync_pending, "staying in wait_move_anim should not set board_sync_pending")
  end)

  it("sync_phase_flags unlocks next_turn_lock on phase change", function()
    local state = _make_state()
    loop_runtime.sync_phase_flags(state, "pre_move")
    local turn_runtime = runtime_state.ensure_turn_runtime(state)
    turn_runtime.next_turn_locked = true
    turn_runtime.next_turn_lock_phase = "pre_move"
    loop_runtime.sync_phase_flags(state, "move")
    _assert_eq(turn_runtime.next_turn_locked, false, "changing phase should unlock next_turn_locked")
  end)

  it("build_board_scene_port returns table", function()
    local state = _make_state()
    local port = loop_runtime.build_board_scene_port(state)
    assert(type(port) == "table", "should return a port table")
    assert(type(port.get_board_scene) == "function", "should have get_board_scene")
  end)

  it("build_board_scene_port get_board_scene returns state.board_scene", function()
    local state = _make_state()
    state.board_scene = { some_scene = true }
    local port = loop_runtime.build_board_scene_port(state)
    _assert_eq(port.get_board_scene(), state.board_scene, "get_board_scene should return state.board_scene")
  end)

  it("build_board_scene_port cached on second call", function()
    local state = _make_state()
    local port1 = loop_runtime.build_board_scene_port(state)
    local port2 = loop_runtime.build_board_scene_port(state)
    _assert_eq(port1, port2, "second call should return cached port")
  end)

  it("build_popup_port returns table with push_popup", function()
    local state = _make_state()
    local port = loop_runtime.build_popup_port(state)
    assert(type(port) == "table", "should return a port table")
    assert(type(port.push_popup) == "function", "should have push_popup function")
  end)

  it("build_popup_port push_popup returns false when no push_popup fn", function()
    local state = _make_state()
    state.push_popup = nil
    local port = loop_runtime.build_popup_port(state)
    local result = port.push_popup(nil, {}, {})
    _assert_eq(result, false, "push_popup should return false when state has no push_popup function")
  end)

  it("build_popup_port cached on second call", function()
    local state = _make_state()
    local port1 = loop_runtime.build_popup_port(state)
    local port2 = loop_runtime.build_popup_port(state)
    _assert_eq(port1, port2, "second call should return cached port")
  end)

  it("build_tip_output_port enqueue falls back to tip_queue when no show_tip", function()
    tip_queue.clear()
    local state = _make_state()
    local port = loop_runtime.build_tip_output_port(state)
    local result = port.enqueue(nil, { text = "hi" })
    _assert_eq(result, true, "enqueue should fall back to tip_queue and return true for valid intent when show_tip is missing")
    tip_queue.clear()
  end)

  it("build_tip_output_port enqueue calls show_tip", function()
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
  end)

  it("build_tip_output_port cached on second call", function()
    local state = _make_state()
    local port1 = loop_runtime.build_tip_output_port(state)
    local port2 = loop_runtime.build_tip_output_port(state)
    _assert_eq(port1, port2, "second call should return cached port")
  end)

  it("build_tile_feedback_port returns table", function()
    local state = _make_state()
    local port = loop_runtime.build_tile_feedback_port(state)
    assert(type(port) == "table", "should return a port table")
    assert(type(port.on_tile_upgraded) == "function", "should have on_tile_upgraded")
  end)

  it("build_tile_feedback_port no game returns false", function()
    local state = _make_state()
    state.game = nil
    local port = loop_runtime.build_tile_feedback_port(state)
    local result = port.on_tile_upgraded(nil, 1, 2)
    _assert_eq(result, false, "no game should return false")
  end)

  it("build_tile_feedback_port cached on second call", function()
    local state = _make_state()
    local port1 = loop_runtime.build_tile_feedback_port(state)
    local port2 = loop_runtime.build_tile_feedback_port(state)
    _assert_eq(port1, port2, "second call should return cached port")
  end)

  it("build_anim_gate_port returns table with flags", function()
    local state = _make_state()
    state.wait_move_anim = true
    state.wait_action_anim = true
    local port = loop_runtime.build_anim_gate_port(state)
    _assert_eq(port.wait_move_anim, true, "wait_move_anim should reflect state")
    _assert_eq(port.wait_action_anim, true, "wait_action_anim should reflect state")
  end)

  it("build_anim_gate_port flags false when not set", function()
    local state = _make_state()
    local port = loop_runtime.build_anim_gate_port(state)
    _assert_eq(port.wait_move_anim, false, "wait_move_anim should be false when not set")
    _assert_eq(port.wait_action_anim, false, "wait_action_anim should be false when not set")
  end)

  it("build_anim_gate_port cached on second call", function()
    local state = _make_state()
    local port1 = loop_runtime.build_anim_gate_port(state)
    local port2 = loop_runtime.build_anim_gate_port(state)
    _assert_eq(port1, port2, "second call should return cached port")
  end)

  it("build_board_visual_feedback_port returns table", function()
    local state = _make_state()
    local port = loop_runtime.build_board_visual_feedback_port(state)
    assert(type(port) == "table", "should return a port table")
    assert(type(port.sync_many) == "function", "should have sync_many")
  end)

  it("build_board_visual_feedback_port cached on second call", function()
    local state = _make_state()
    local port1 = loop_runtime.build_board_visual_feedback_port(state)
    local port2 = loop_runtime.build_board_visual_feedback_port(state)
    _assert_eq(port1, port2, "second call should return cached port")
  end)

  it("build_board_visual_feedback_port sync_many no callback returns false", function()
    local state = _make_state()
    state.on_board_visual_sync = nil
    local port = loop_runtime.build_board_visual_feedback_port(state)
    local result = port.sync_many({}, nil)
    _assert_eq(result, false, "sync_many with no callback should return false")
  end)
end)
