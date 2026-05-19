local gameplay_loop_ports = require("src.turn.loop.ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain loop ports coverage", function()
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

  it("resolve empty table returns base ports", function()
    local ports = gameplay_loop_ports.resolve({})
    assert(type(ports.modal) == "table", "resolve({}) should include modal group")
    assert(type(ports.modal.close_choice_modal) == "function",
      "modal group should have close_choice_modal fn")
  end)

  it("resolve legacy flat override errors", function()
    local ok, err = pcall(function()
      gameplay_loop_ports.resolve({ close_choice_modal = function() end })
    end)
    _assert_eq(ok, false, "legacy flat override should raise an error")
    assert(tostring(err):find("legacy flat", 1, true) ~= nil,
      "error message should mention 'legacy flat'")
  end)

  it("resolve non-table override errors", function()
    local ok, _ = pcall(function()
      gameplay_loop_ports.resolve("not_a_table")
    end)
    _assert_eq(ok, false, "non-table override should raise an error")
  end)

  it("resolve table without group keys uses base ports", function()
    local ports = gameplay_loop_ports.resolve({ some_other_key = "value" })
    assert(type(ports.modal) == "table", "no-group-key table should use base modal ports")
    assert(type(ports.clock.wall_now_seconds) == "function",
      "no-group-key table should use base clock ports")
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

  it("resolve override extra keys included", function()
    local extra_fn = function() return "extra" end
    local ports = gameplay_loop_ports.resolve({
      modal = {
        open_choice_modal = function() end,
        extra_non_required_key = extra_fn,
      },
    })
    _assert_eq(ports.modal.extra_non_required_key, extra_fn,
      "extra key in override group should be included in resolved ports")
  end)

  it("build_noop_group returns callable noops", function()
    local group = gameplay_loop_ports._build_noop_group({ "x", "y" })
    assert(type(group.x) == "function", "x should be a function")
    assert(type(group.y) == "function", "y should be a function")
    _assert_eq(group.x(), nil, "noop x should return nil")
    _assert_eq(group.y(), nil, "noop y should return nil")
  end)

  it("build_noop_group with overrides prefers override", function()
    local custom = function() return 77 end
    local group = gameplay_loop_ports._build_noop_group({ "a", "b" }, { a = custom })
    _assert_eq(group.a, custom, "overridden key should be the custom fn")
    assert(type(group.b) == "function", "non-overridden key should still be a function")
    _assert_eq(group.b(), nil, "non-overridden key should return nil")
  end)

  it("build_noop_group includes extra override keys", function()
    local extra_fn = function() return "extra" end
    local group = gameplay_loop_ports._build_noop_group({ "a" }, { b = extra_fn })
    assert(type(group.a) == "function", "declared key should still be present")
    _assert_eq(group.b, extra_fn, "extra key from overrides should be included")
  end)

  it("describe_contract group_names includes all groups", function()
    local contract = gameplay_loop_ports.describe_contract()
    local group_set = {}
    for _, name in ipairs(contract.group_names) do
      group_set[name] = true
    end
    for _, expected in ipairs({ "modal", "anim", "ui_sync", "debug", "clock", "state", "output" }) do
      assert(group_set[expected] == true,
        "describe_contract group_names should include " .. expected)
    end
  end)

  it("describe_contract returns independent copies", function()
    local contract1 = gameplay_loop_ports.describe_contract()
    local contract2 = gameplay_loop_ports.describe_contract()
    assert(contract1.group_names ~= contract2.group_names,
      "each describe_contract call should return fresh group_names")
    assert(contract1.port_groups.modal ~= contract2.port_groups.modal,
      "each describe_contract call should return fresh port_groups.modal")
  end)

  it("describe_contract port_groups contain expected keys per group", function()
    local contract = gameplay_loop_ports.describe_contract()
    local function _keys_set(group_name)
      local set = {}
      for _, k in ipairs(contract.port_groups[group_name]) do set[k] = true end
      return set
    end
    local modal_keys = _keys_set("modal")
    assert(modal_keys.close_choice_modal == true, "modal should include close_choice_modal")
    assert(modal_keys.open_choice_modal == true, "modal should include open_choice_modal")
    local clock_keys = _keys_set("clock")
    assert(clock_keys.wall_now_seconds == true, "clock should include wall_now_seconds")
    assert(clock_keys.wall_diff_seconds == true, "clock should include wall_diff_seconds")
    assert(clock_keys.cpu_now_seconds == true, "clock should include cpu_now_seconds")
    local output_keys = _keys_set("output")
    for _, expected in ipairs({
      "invalidate_ui_model", "clear_ui_dirty", "is_ui_dirty",
      "sync_ui_model", "get_ui_model",
      "sync_pending_choice", "clear_pending_choice", "get_pending_choice",
      "get_pending_choice_id", "get_pending_choice_elapsed",
      "set_pending_choice_elapsed", "set_pending_choice_id",
      "sync_modal_timer", "get_modal_elapsed", "get_modal_ref",
    }) do
      assert(output_keys[expected] == true, "output should include " .. expected)
    end
    local state_keys = _keys_set("state")
    for _, expected in ipairs({
      "apply_role_control_lock", "install_event_handlers", "on_bankruptcy_tiles_cleared",
    }) do
      assert(state_keys[expected] == true, "state should include " .. expected)
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
