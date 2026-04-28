local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")

-- Tests for _build_ui_gate in loop_ui_sync_defaults.lua
-- Note: _build_ui_gate is a local function, we test via the public resolve_ui_gate function
local _build_ui_gate_tests = {
  function()
    -- Test resolve_ui_gate with empty state (nil ui)
    local ports = loop_ui_sync_defaults.build_base_ui_sync_ports(function() end, function() end)
    local result = ports.resolve_ui_gate({})
    assert(type(result) == "table", "should return a table")
    assert(result.input_blocked == false, "input_blocked should be false when ui is nil")
    assert(result.choice_active == false, "choice_active should be false when ui is nil")
    assert(result.market_active == false, "market_active should be false when ui is nil")
    assert(result.popup_active == false, "popup_active should be false when ui is nil")
  end,
  function()
    -- Test resolve_ui_gate with all ui flags true
    local ports = loop_ui_sync_defaults.build_base_ui_sync_ports(function() end, function() end)
    local state = {
      ui = {
        input_blocked = true,
        choice_active = true,
        market_active = true,
        popup_active = true,
        popup_seq = 123,
        popup_owner_index = 2,
        popup_payload = { auto_close_seconds = 5 },
      }
    }
    local result = ports.resolve_ui_gate(state)
    assert(result.input_blocked == true, "input_blocked should be true")
    assert(result.choice_active == true, "choice_active should be true")
    assert(result.market_active == true, "market_active should be true")
    assert(result.popup_active == true, "popup_active should be true")
    assert(result.popup_seq == 123, "popup_seq should be preserved")
    assert(result.popup_owner_index == 2, "popup_owner_index should be preserved")
    assert(result.popup_auto_close_seconds == 5, "popup_auto_close_seconds should be 5")
  end,
}

return {
  name = "ui_sync_gates",
  tests = {
    { name = "_test_build_ui_gate_nil_ui", run = _build_ui_gate_tests[1] },
    { name = "_test_build_ui_gate_all_true", run = _build_ui_gate_tests[2] },
  },
}
