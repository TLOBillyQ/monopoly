local gameplay_loop_ports = require("src.turn.loop.ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- _clock_diff fallback: non-numeric args return 0


-- _copy_group_ports: extra override keys not in required_keys are included


-- _resolve_grouped_override paths


-- _build_resolved_ports with grouped_override merges all groups


-- debug group has resolve_event_log_enabled returning false by default


-- describe_contract returns independent copies


-- state and output groups present


-- _build_noop_group with empty keys list

describe("domain loop ports extended coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("clock wall_diff non-numeric returns zero", function()
    local ports = gameplay_loop_ports.resolve(nil)
    local diff = ports.clock.wall_diff_seconds(nil, 5.0)
    _assert_eq(diff, 0, "wall_diff_seconds with nil arg should return 0")
  end)

  it("clock cpu_diff non-numeric returns zero", function()
    local ports = gameplay_loop_ports.resolve(nil)
    local diff = ports.clock.cpu_diff_seconds("bad", 2.0)
    _assert_eq(diff, 0, "cpu_diff_seconds with non-numeric arg should return 0")
  end)

  it("clock wall_diff numeric returns correct diff", function()
    local ports = gameplay_loop_ports.resolve(nil)
    local diff = ports.clock.wall_diff_seconds(10.5, 8.0)
    _assert_eq(diff, 2.5, "wall_diff_seconds with valid args should return difference")
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

  it("resolve table without group keys uses base ports", function()
    local ports = gameplay_loop_ports.resolve({ some_other_key = "value" })
    assert(type(ports.modal) == "table", "no-group-key table should use base modal ports")
    assert(type(ports.clock.wall_now_seconds) == "function",
      "no-group-key table should use base clock ports")
  end)

  it("resolve full override merges all groups", function()
    local custom_modal_open = function() return "custom" end
    local custom_anim_play = function() return "custom_anim" end
    local ports = gameplay_loop_ports.resolve({
      modal = { open_choice_modal = custom_modal_open },
      anim = { play_move_anim = custom_anim_play },
    })
    _assert_eq(ports.modal.open_choice_modal, custom_modal_open,
      "modal override should be in resolved ports")
    _assert_eq(ports.anim.play_move_anim, custom_anim_play,
      "anim override should be in resolved ports")
    assert(type(ports.clock.wall_now_seconds) == "function",
      "non-overridden clock group should still be present")
    assert(type(ports.output.invalidate_ui_model) == "function",
      "non-overridden output group should still be present")
  end)

  it("debug resolve_event_log_enabled defaults false", function()
    local ports = gameplay_loop_ports.resolve(nil)
    _assert_eq(ports.debug.resolve_event_log_enabled(), false,
      "debug.resolve_event_log_enabled should return false by default")
  end)

  it("describe_contract clock group has expected keys", function()
    local contract = gameplay_loop_ports.describe_contract()
    local clock_keys = {}
    for _, k in ipairs(contract.port_groups.clock) do
      clock_keys[k] = true
    end
    assert(clock_keys.wall_now_seconds == true,
      "clock port_groups should include wall_now_seconds")
    assert(clock_keys.wall_diff_seconds == true,
      "clock port_groups should include wall_diff_seconds")
    assert(clock_keys.cpu_now_seconds == true,
      "clock port_groups should include cpu_now_seconds")
  end)

  it("resolve nil includes state and output groups", function()
    local ports = gameplay_loop_ports.resolve(nil)
    assert(type(ports.state) == "table", "state group should be present")
    assert(type(ports.state.apply_role_control_lock) == "function",
      "state.apply_role_control_lock should be a function")
    assert(type(ports.output.sync_pending_choice) == "function",
      "output.sync_pending_choice should be a function")
  end)

  it("build_noop_group empty keys with overrides", function()
    local extra = function() return 42 end
    local group = gameplay_loop_ports._build_noop_group({}, { my_key = extra })
    _assert_eq(group.my_key, extra, "empty keys with override should include override key")
  end)
end)
