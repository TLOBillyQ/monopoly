local gameplay_loop_ports = require("src.turn.loop.ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function test_resolve_nil_returns_base_ports_with_all_groups()
  local ports = gameplay_loop_ports.resolve(nil)
  assert(type(ports) == "table", "resolve(nil) should return a table")
  assert(type(ports.modal) == "table", "resolve(nil) should include modal group")
  assert(type(ports.anim) == "table", "resolve(nil) should include anim group")
  assert(type(ports.ui_sync) == "table", "resolve(nil) should include ui_sync group")
  assert(type(ports.clock) == "table", "resolve(nil) should include clock group")
  assert(type(ports.output) == "table", "resolve(nil) should include output group")
end

local function test_resolve_empty_table_returns_base_ports()
  local ports = gameplay_loop_ports.resolve({})
  assert(type(ports.modal) == "table", "resolve({}) should include modal group")
  assert(type(ports.modal.close_choice_modal) == "function",
    "modal group should have close_choice_modal fn")
end

local function test_resolve_grouped_override_merges_specified_port()
  local custom_fn = function() return "custom_open" end
  local ports = gameplay_loop_ports.resolve({
    modal = { open_choice_modal = custom_fn },
  })
  _assert_eq(ports.modal.open_choice_modal, custom_fn, "grouped override should replace specified port fn")
  assert(type(ports.modal.close_choice_modal) == "function",
    "non-overridden port should remain a function from base")
  assert(type(ports.anim) == "table", "non-overridden group should still be present")
end

local function test_resolve_grouped_override_non_overridden_groups_use_base()
  local ports = gameplay_loop_ports.resolve({ modal = {} })
  assert(type(ports.output.invalidate_ui_model) == "function",
    "non-overridden output group should keep base invalidate_ui_model")
  assert(type(ports.clock.wall_now_seconds) == "function",
    "non-overridden clock group should keep base wall_now_seconds")
end

local function test_resolve_legacy_flat_override_errors()
  local ok, err = pcall(function()
    gameplay_loop_ports.resolve({ close_choice_modal = function() end })
  end)
  _assert_eq(ok, false, "legacy flat override should raise an error")
  assert(tostring(err):find("legacy flat", 1, true) ~= nil,
    "error message should mention 'legacy flat'")
end

local function test_resolve_non_table_override_errors()
  local ok, _ = pcall(function()
    gameplay_loop_ports.resolve("not_a_table")
  end)
  _assert_eq(ok, false, "non-table override should raise an error")
end

local function test_build_noop_group_returns_callable_noops()
  local group = gameplay_loop_ports._build_noop_group({ "x", "y" })
  assert(type(group.x) == "function", "x should be a function")
  assert(type(group.y) == "function", "y should be a function")
  _assert_eq(group.x(), nil, "noop x should return nil")
  _assert_eq(group.y(), nil, "noop y should return nil")
end

local function test_build_noop_group_with_overrides_prefers_override()
  local custom = function() return 77 end
  local group = gameplay_loop_ports._build_noop_group({ "a", "b" }, { a = custom })
  _assert_eq(group.a, custom, "overridden key should be the custom fn")
  assert(type(group.b) == "function", "non-overridden key should still be a function")
  _assert_eq(group.b(), nil, "non-overridden key should return nil")
end

local function test_build_noop_group_includes_extra_override_keys()
  local extra_fn = function() return "extra" end
  local group = gameplay_loop_ports._build_noop_group({ "a" }, { b = extra_fn })
  assert(type(group.a) == "function", "declared key should still be present")
  _assert_eq(group.b, extra_fn, "extra key from overrides should be included")
end

local function test_describe_contract_returns_group_names_and_port_groups()
  local contract = gameplay_loop_ports.describe_contract()
  assert(type(contract.group_names) == "table",
    "describe_contract should return group_names table")
  assert(type(contract.port_groups) == "table",
    "describe_contract should return port_groups table")
end

local function test_describe_contract_group_names_includes_all_groups()
  local contract = gameplay_loop_ports.describe_contract()
  local group_set = {}
  for _, name in ipairs(contract.group_names) do
    group_set[name] = true
  end
  for _, expected in ipairs({ "modal", "anim", "ui_sync", "debug", "clock", "state", "output" }) do
    assert(group_set[expected] == true,
      "describe_contract group_names should include " .. expected)
  end
end

local function test_describe_contract_port_groups_are_independent_copies()
  local contract1 = gameplay_loop_ports.describe_contract()
  local contract2 = gameplay_loop_ports.describe_contract()
  assert(contract1.group_names ~= contract2.group_names,
    "each describe_contract call should return fresh group_names")
  assert(contract1.port_groups.modal ~= contract2.port_groups.modal,
    "each describe_contract call should return fresh port_groups.modal")
end

local function test_describe_contract_port_groups_contain_expected_keys()
  local contract = gameplay_loop_ports.describe_contract()
  local modal_keys = {}
  for _, k in ipairs(contract.port_groups.modal) do
    modal_keys[k] = true
  end
  assert(modal_keys.close_choice_modal == true,
    "modal port_groups should include close_choice_modal")
  assert(modal_keys.open_choice_modal == true,
    "modal port_groups should include open_choice_modal")
end

return {
  name = "domain loop ports coverage",
  tests = {
    { name = "resolve nil returns base ports with all groups", run = test_resolve_nil_returns_base_ports_with_all_groups },
    { name = "resolve empty table returns base ports", run = test_resolve_empty_table_returns_base_ports },
    { name = "resolve grouped override merges specified port", run = test_resolve_grouped_override_merges_specified_port },
    { name = "resolve grouped override non-overridden groups use base", run = test_resolve_grouped_override_non_overridden_groups_use_base },
    { name = "resolve legacy flat override errors", run = test_resolve_legacy_flat_override_errors },
    { name = "resolve non-table override errors", run = test_resolve_non_table_override_errors },
    { name = "build_noop_group returns callable noops", run = test_build_noop_group_returns_callable_noops },
    { name = "build_noop_group with overrides prefers override", run = test_build_noop_group_with_overrides_prefers_override },
    { name = "build_noop_group includes extra override keys", run = test_build_noop_group_includes_extra_override_keys },
    { name = "describe_contract returns group_names and port_groups", run = test_describe_contract_returns_group_names_and_port_groups },
    { name = "describe_contract group_names includes all groups", run = test_describe_contract_group_names_includes_all_groups },
    { name = "describe_contract port_groups are independent copies", run = test_describe_contract_port_groups_are_independent_copies },
    { name = "describe_contract port_groups contain expected keys", run = test_describe_contract_port_groups_contain_expected_keys },
  },
}
