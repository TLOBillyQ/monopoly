local gameplay_loop_ports = require("src.turn.loop.ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain loop ports coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("resolve nil returns base ports with all groups", function()
    local ports = gameplay_loop_ports.resolve(nil)
    assert(type(ports) == "table", "resolve(nil) should return a table")
    assert(type(ports.modal) == "table", "resolve(nil) should include modal group")
    assert(type(ports.anim) == "table", "resolve(nil) should include anim group")
    assert(type(ports.ui_sync) == "table", "resolve(nil) should include ui_sync group")
    assert(type(ports.clock) == "table", "resolve(nil) should include clock group")
    assert(type(ports.output) == "table", "resolve(nil) should include output group")
  end)

  it("resolve empty table returns base ports", function()
    local ports = gameplay_loop_ports.resolve({})
    assert(type(ports.modal) == "table", "resolve({}) should include modal group")
    assert(type(ports.modal.close_choice_modal) == "function",
      "modal group should have close_choice_modal fn")
  end)

  it("resolve grouped override merges specified port", function()
    local custom_fn = function() return "custom_open" end
    local ports = gameplay_loop_ports.resolve({
      modal = { open_choice_modal = custom_fn },
    })
    _assert_eq(ports.modal.open_choice_modal, custom_fn, "grouped override should replace specified port fn")
    assert(type(ports.modal.close_choice_modal) == "function",
      "non-overridden port should remain a function from base")
    assert(type(ports.anim) == "table", "non-overridden group should still be present")
  end)

  it("resolve grouped override non-overridden groups use base", function()
    local ports = gameplay_loop_ports.resolve({ modal = {} })
    assert(type(ports.output.invalidate_ui_model) == "function",
      "non-overridden output group should keep base invalidate_ui_model")
    assert(type(ports.clock.wall_now_seconds) == "function",
      "non-overridden clock group should keep base wall_now_seconds")
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

  it("describe_contract returns group_names and port_groups", function()
    local contract = gameplay_loop_ports.describe_contract()
    assert(type(contract.group_names) == "table",
      "describe_contract should return group_names table")
    assert(type(contract.port_groups) == "table",
      "describe_contract should return port_groups table")
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

  it("describe_contract port_groups are independent copies", function()
    local contract1 = gameplay_loop_ports.describe_contract()
    local contract2 = gameplay_loop_ports.describe_contract()
    assert(contract1.group_names ~= contract2.group_names,
      "each describe_contract call should return fresh group_names")
    assert(contract1.port_groups.modal ~= contract2.port_groups.modal,
      "each describe_contract call should return fresh port_groups.modal")
  end)

  it("describe_contract port_groups contain expected keys", function()
    local contract = gameplay_loop_ports.describe_contract()
    local modal_keys = {}
    for _, k in ipairs(contract.port_groups.modal) do
      modal_keys[k] = true
    end
    assert(modal_keys.close_choice_modal == true,
      "modal port_groups should include close_choice_modal")
    assert(modal_keys.open_choice_modal == true,
      "modal port_groups should include open_choice_modal")
  end)
end)
