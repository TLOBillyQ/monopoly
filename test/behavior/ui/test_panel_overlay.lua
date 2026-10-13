require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- panel_overlay.lua 直测:settlement 类型判定(遍历序、choice_active 排除、
-- 多 flag 优先级)与 overlay 可见性。

local panel_overlay = require("src.ui.state.panel_overlay")
describe("TestPanelOverlay", function()
it("test_nil_ui_yields_no_settlement", function()
  luassert.truthy(panel_overlay.settlement_type(nil) == nil, "nil ui -> nil")
  luassert.truthy(panel_overlay.settlement_type_excluding_choice(nil) == nil, "nil ui -> nil (excluding)")
end)

it("test_no_flags_yields_no_settlement", function()
  luassert.truthy(panel_overlay.settlement_type({}) == nil, "no flags -> nil")
end)

it("test_first_matching_flag_in_order_wins", function()
  luassert.truthy(panel_overlay.settlement_type({ market_active = true, move_active = true }) == "黑市",
    "the first matching settlement flag must win")
end)

it("test_settlement_type_returns_the_choice_name", function()
  luassert.truthy(panel_overlay.settlement_type({ choice_active = true }) == "机会",
    "choice_active maps to the choice settlement name")
end)

it("test_excluding_choice_skips_only_the_choice_flag", function()
  luassert.truthy(panel_overlay.settlement_type_excluding_choice({ choice_active = true }) == nil,
    "choice_active alone must be excluded")
  luassert.truthy(panel_overlay.settlement_type_excluding_choice({ move_active = true }) == "移动",
    "non-choice flags must still match")
  luassert.truthy(panel_overlay.settlement_type_excluding_choice({ choice_active = true, move_active = true }) == "移动",
    "later non-choice flags must still be found after the excluded one")
end)

it("test_is_settling_reads_state_ui", function()
  luassert.truthy(panel_overlay.is_settling({ ui = { popup_active = true } }) == true, "a flag set -> settling")
  luassert.truthy(panel_overlay.is_settling({}) == false, "no ui -> not settling")
  luassert.truthy(panel_overlay.is_settling(nil) == false, "nil state -> not settling")
end)

end)
