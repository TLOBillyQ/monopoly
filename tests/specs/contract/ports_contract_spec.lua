local gameplay_loop_ports = require("turn.ports")
local assertions = require("support.assertions")

local function _all_groups_present(ports)
  assertions.assert_truthy(type(ports.modal) == "table", "missing modal ports")
  assertions.assert_truthy(type(ports.anim) == "table", "missing anim ports")
  assertions.assert_truthy(type(ports.ui_sync) == "table", "missing ui_sync ports")
  assertions.assert_truthy(type(ports.debug) == "table", "missing debug ports")
  assertions.assert_truthy(type(ports.state) == "table", "missing state ports")
end

local function _test_resolve_returns_grouped_ports()
  local ports = gameplay_loop_ports.resolve(nil)
  _all_groups_present(ports)
  assertions.assert_truthy(type(ports.ui_sync.set_input_blocked) == "function", "set_input_blocked should exist")
end

local function _test_set_input_blocked_return_semantics()
  local ports = gameplay_loop_ports.resolve({
    ui_sync = {},
  })
  local state = { ui = { input_blocked = false } }
  local changed_1 = ports.ui_sync.set_input_blocked(state, true)
  local changed_2 = ports.ui_sync.set_input_blocked(state, true)
  local changed_3 = ports.ui_sync.set_input_blocked(state, false)
  assertions.assert_equal(changed_1, true, "first set_input_blocked should report changed")
  assertions.assert_equal(changed_2, false, "idempotent set_input_blocked should report unchanged")
  assertions.assert_equal(changed_3, true, "toggling set_input_blocked should report changed")
end

local function _test_override_keeps_fallback_fields()
  local hit = false
  local ports = gameplay_loop_ports.resolve({
    ui_sync = {
      apply_input_lock = function()
        hit = true
      end,
    },
  })
  ports.ui_sync.apply_input_lock({})
  assertions.assert_equal(hit, true, "override apply_input_lock should be used")
  assertions.assert_truthy(type(ports.ui_sync.update_countdown) == "function", "fallback ui_sync field should remain")
end

return {
  layer = "contract",
  domain = "ports",
  cases = {
    {
      id = "given_nil_override_when_resolve_then_grouped_ports_present",
      desc = "resolve nil override returns grouped ports",
      run = _test_resolve_returns_grouped_ports,
    },
    {
      id = "given_ui_state_when_set_input_blocked_then_return_changed_semantics",
      desc = "set_input_blocked changed semantics",
      run = _test_set_input_blocked_return_semantics,
    },
    {
      id = "given_partial_override_when_resolve_then_unset_fields_keep_fallback",
      desc = "override merged with fallback fields",
      run = _test_override_keeps_fallback_fields,
    },
  },
}
