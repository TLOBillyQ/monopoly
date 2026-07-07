local loop_ui_sync_defaults = require("src.turn.output.ui_sync_defaults")

-- turn 层不再解析 state.ui.* 门控键名：base 端口返回全关的惰性 gate，
-- fill 只从端口 resolve_ui_gate 的 gate 值对象派生逐项查询。
local _ui_gate_default_tests = {
  function()
    -- base resolve_ui_gate 不读 state.ui：即使 state.ui 全开也返回惰性 gate
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
    assert(type(result) == "table", "should return a table")
    assert(result.input_blocked == false, "inert gate should keep input_blocked false")
    assert(result.choice_active == false, "inert gate should keep choice_active false")
    assert(result.market_active == false, "inert gate should keep market_active false")
    assert(result.popup_active == false, "inert gate should keep popup_active false")
    assert(result.popup_seq == nil, "inert gate should keep popup_seq nil")
    assert(result.popup_owner_index == nil, "inert gate should keep popup_owner_index nil")
    assert(result.popup_auto_close_seconds == nil, "inert gate should keep popup_auto_close_seconds nil")
  end,
  function()
    -- fill 派生的 is_* / get_popup_owner_index 全部经由端口 resolve_ui_gate
    local base = loop_ui_sync_defaults.build_base_ui_sync_ports(function() end, function() end)
    local gate = {
      input_blocked = true,
      choice_active = false,
      market_active = true,
      popup_active = true,
      popup_seq = 123,
      popup_owner_index = 2,
      popup_auto_close_seconds = 5,
    }
    local ports = {
      resolve_ui_gate = function() return gate end,
    }
    loop_ui_sync_defaults.fill_ui_sync_defaults(ports, base)
    assert(ports.is_input_blocked({}) == true, "is_input_blocked should come from resolve_ui_gate")
    assert(ports.is_choice_active({}) == false, "is_choice_active should come from resolve_ui_gate")
    assert(ports.is_popup_active({}) == true, "is_popup_active should come from resolve_ui_gate")
    assert(ports.get_popup_owner_index({}) == 2, "get_popup_owner_index should come from resolve_ui_gate")
  end,
}

describe("ui_sync_gates", function()
  it("_test_base_resolve_ui_gate_is_inert", _ui_gate_default_tests[1])

  it("_test_fill_derives_queries_from_resolve_ui_gate", _ui_gate_default_tests[2])
end)
