local gameplay_loop_ports = require("src.turn.loop.ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain loop ports base invocation coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("base modal ports are no-op and return nil when invoked", function()
    local ports = gameplay_loop_ports.resolve(nil)
    _assert_eq(ports.modal.close_choice_modal(), nil, "close_choice_modal noop returns nil")
    _assert_eq(ports.modal.open_choice_modal(), nil, "open_choice_modal noop returns nil")
    _assert_eq(ports.modal.close_popup(), nil, "close_popup noop returns nil")
  end)

  it("base anim ports are no-op when invoked", function()
    local ports = gameplay_loop_ports.resolve(nil)
    _assert_eq(ports.anim.play_move_anim(), nil, "play_move_anim noop returns nil")
    _assert_eq(ports.anim.play_action_anim(), nil, "play_action_anim noop returns nil")
    _assert_eq(ports.anim.reset_status_3d(), nil, "reset_status_3d noop returns nil")
    _assert_eq(ports.anim.sync_status_3d(), nil, "sync_status_3d noop returns nil")
  end)

  it("base state ports are no-op when invoked", function()
    local ports = gameplay_loop_ports.resolve(nil)
    _assert_eq(ports.state.apply_role_control_lock(), nil, "apply_role_control_lock noop returns nil")
    _assert_eq(ports.state.install_event_handlers(), nil, "install_event_handlers noop returns nil")
    _assert_eq(ports.state.on_bankruptcy_tiles_cleared(), nil, "on_bankruptcy_tiles_cleared noop returns nil")
  end)

  it("base debug ports are no-op except resolve_event_log_enabled returns false", function()
    local ports = gameplay_loop_ports.resolve(nil)
    _assert_eq(ports.debug.log_status(), nil, "log_status noop returns nil")
    _assert_eq(ports.debug.sync_event_log(), nil, "sync_event_log noop returns nil")
    _assert_eq(ports.debug.resolve_event_log_enabled(), false, "resolve_event_log_enabled returns false")
  end)

  it("base clock ports return zero for now and zero for diff with nil args", function()
    local ports = gameplay_loop_ports.resolve(nil)
    _assert_eq(ports.clock.wall_now_seconds(), 0, "wall_now_seconds returns 0")
    _assert_eq(ports.clock.cpu_now_seconds(), 0, "cpu_now_seconds returns 0")
    _assert_eq(ports.clock.wall_diff_seconds(nil, 1.0), 0, "wall_diff with nil first arg returns 0")
    _assert_eq(ports.clock.cpu_diff_seconds(2.0, nil), 0, "cpu_diff with nil second arg returns 0")
    _assert_eq(ports.clock.wall_diff_seconds(5.0, 3.0), 2.0, "wall_diff with both numeric args returns difference")
    _assert_eq(ports.clock.cpu_diff_seconds(10.0, 1.5), 8.5, "cpu_diff with both numeric args returns difference")
  end)

  it("base ui_sync ports include all declared keys as functions", function()
    local ports = gameplay_loop_ports.resolve(nil)
    local expected = {
      "apply_input_lock", "step_choice_timeout", "step_modal_timeout",
      "update_countdown", "resolve_ui_gate", "build_model", "refresh_from_dirty", "follow_camera",
      "sync_camera_position", "get_ui_state", "is_input_blocked",
      "is_popup_active", "is_choice_active", "is_market_active",
      "get_popup_owner_index", "set_input_blocked",
    }
    for _, key in ipairs(expected) do
      assert(type(ports.ui_sync[key]) == "function",
        "ui_sync." .. key .. " should be a function")
    end
  end)

  it("base output port invalidate_ui_model actually toggles dirty flag", function()
    local ports = gameplay_loop_ports.resolve(nil)
    local state = {}
    _assert_eq(ports.output.is_ui_dirty(state), false, "fresh state not dirty")
    _assert_eq(ports.output.invalidate_ui_model(state), true, "first invalidate returns true")
    _assert_eq(ports.output.is_ui_dirty(state), true, "state dirty after invalidate")
    _assert_eq(ports.output.invalidate_ui_model(state), false, "second invalidate returns false (already dirty)")
  end)

  it("override on output group: custom invalidate is used, others fallback", function()
    local custom_called = 0
    local custom_invalidate = function() custom_called = custom_called + 1; return "custom" end
    local ports = gameplay_loop_ports.resolve({
      output = { invalidate_ui_model = custom_invalidate },
    })
    local result = ports.output.invalidate_ui_model({})
    _assert_eq(custom_called, 1, "custom invalidate should be called")
    _assert_eq(result, "custom", "custom return propagates")
    assert(type(ports.output.sync_ui_model) == "function",
      "sync_ui_model should remain base function (not overridden)")
  end)

  it("override on debug group preserves resolve_event_log_enabled override", function()
    local ports = gameplay_loop_ports.resolve({
      debug = { resolve_event_log_enabled = function() return true end },
    })
    _assert_eq(ports.debug.resolve_event_log_enabled(), true, "overridden debug return value applies")
    _assert_eq(ports.debug.log_status(), nil, "non-overridden debug noop preserved")
  end)

  it("describe_contract output_groups expose all output port names", function()
    local contract = gameplay_loop_ports.describe_contract()
    local output_keys = {}
    for _, k in ipairs(contract.port_groups.output) do
      output_keys[k] = true
    end
    for _, expected in ipairs({
      "invalidate_ui_model", "clear_ui_dirty", "is_ui_dirty",
      "sync_ui_model", "get_ui_model",
      "sync_pending_choice", "clear_pending_choice", "get_pending_choice",
      "get_pending_choice_id", "get_pending_choice_elapsed",
      "set_pending_choice_elapsed", "set_pending_choice_id",
      "sync_modal_timer", "get_modal_elapsed", "get_modal_ref",
    }) do
      assert(output_keys[expected] == true,
        "describe_contract.port_groups.output should include " .. expected)
    end
  end)

  it("describe_contract state_groups expose all state port names", function()
    local contract = gameplay_loop_ports.describe_contract()
    local state_keys = {}
    for _, k in ipairs(contract.port_groups.state) do
      state_keys[k] = true
    end
    for _, expected in ipairs({
      "apply_role_control_lock",
      "install_event_handlers",
      "on_bankruptcy_tiles_cleared",
    }) do
      assert(state_keys[expected] == true,
        "describe_contract.port_groups.state should include " .. expected)
    end
  end)

  it("repeated resolve(nil) returns independent group tables (no shared mutation)", function()
    local ports1 = gameplay_loop_ports.resolve(nil)
    local ports2 = gameplay_loop_ports.resolve(nil)
    assert(ports1 ~= ports2, "each resolve should return new top-level table")
    assert(ports1.modal ~= ports2.modal, "modal group should be independent")
    assert(ports1.output ~= ports2.output, "output group should be independent")
  end)
end)
