local gameplay_loop_ports = require("src.turn.loop.ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- _clock_diff fallback: non-numeric args return 0

local function test_clock_wall_diff_non_numeric_returns_zero()
  local ports = gameplay_loop_ports.resolve(nil)
  local diff = ports.clock.wall_diff_seconds(nil, 5.0)
  _assert_eq(diff, 0, "wall_diff_seconds with nil arg should return 0")
end

local function test_clock_cpu_diff_non_numeric_returns_zero()
  local ports = gameplay_loop_ports.resolve(nil)
  local diff = ports.clock.cpu_diff_seconds("bad", 2.0)
  _assert_eq(diff, 0, "cpu_diff_seconds with non-numeric arg should return 0")
end

local function test_clock_wall_diff_numeric_returns_correct_diff()
  local ports = gameplay_loop_ports.resolve(nil)
  local diff = ports.clock.wall_diff_seconds(10.5, 8.0)
  _assert_eq(diff, 2.5, "wall_diff_seconds with valid args should return difference")
end

-- _copy_group_ports: extra override keys not in required_keys are included

local function test_resolve_override_extra_keys_included()
  local extra_fn = function() return "extra" end
  local ports = gameplay_loop_ports.resolve({
    modal = {
      open_choice_modal = function() end,
      extra_non_required_key = extra_fn,
    },
  })
  _assert_eq(ports.modal.extra_non_required_key, extra_fn,
    "extra key in override group should be included in resolved ports")
end

-- _resolve_grouped_override paths

local function test_resolve_table_without_group_keys_uses_base_ports()
  local ports = gameplay_loop_ports.resolve({ some_other_key = "value" })
  assert(type(ports.modal) == "table", "no-group-key table should use base modal ports")
  assert(type(ports.clock.wall_now_seconds) == "function",
    "no-group-key table should use base clock ports")
end

-- _build_resolved_ports with grouped_override merges all groups

local function test_resolve_full_override_merges_all_groups()
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
end

-- debug group has resolve_debug_enabled returning false by default

local function test_debug_resolve_debug_enabled_returns_false_by_default()
  local ports = gameplay_loop_ports.resolve(nil)
  _assert_eq(ports.debug.resolve_debug_enabled(), false,
    "debug.resolve_debug_enabled should return false by default")
end

-- describe_contract returns independent copies

local function test_describe_contract_clock_group_has_expected_keys()
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
end

-- state and output groups present

local function test_resolve_nil_includes_state_and_output_groups()
  local ports = gameplay_loop_ports.resolve(nil)
  assert(type(ports.state) == "table", "state group should be present")
  assert(type(ports.state.apply_role_control_lock) == "function",
    "state.apply_role_control_lock should be a function")
  assert(type(ports.output.sync_pending_choice) == "function",
    "output.sync_pending_choice should be a function")
end

-- _build_noop_group with empty keys list

local function test_build_noop_group_empty_keys_with_overrides()
  local extra = function() return 42 end
  local group = gameplay_loop_ports._build_noop_group({}, { my_key = extra })
  _assert_eq(group.my_key, extra, "empty keys with override should include override key")
end

return {
  name = "domain loop ports extended coverage",
  tests = {
    { name = "clock wall_diff non-numeric returns zero", run = test_clock_wall_diff_non_numeric_returns_zero },
    { name = "clock cpu_diff non-numeric returns zero", run = test_clock_cpu_diff_non_numeric_returns_zero },
    { name = "clock wall_diff numeric returns correct diff", run = test_clock_wall_diff_numeric_returns_correct_diff },
    { name = "resolve override extra keys included", run = test_resolve_override_extra_keys_included },
    { name = "resolve table without group keys uses base ports", run = test_resolve_table_without_group_keys_uses_base_ports },
    { name = "resolve full override merges all groups", run = test_resolve_full_override_merges_all_groups },
    { name = "debug resolve_debug_enabled returns false by default", run = test_debug_resolve_debug_enabled_returns_false_by_default },
    { name = "describe_contract clock group has expected keys", run = test_describe_contract_clock_group_has_expected_keys },
    { name = "resolve nil includes state and output groups", run = test_resolve_nil_includes_state_and_output_groups },
    { name = "build_noop_group empty keys with overrides", run = test_build_noop_group_empty_keys_with_overrides },
  },
}
