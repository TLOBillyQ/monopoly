-- Direct coverage for src.ui.view.choice_support option-id/label/lookup shapes
-- and secondary-confirm-body fallbacks. These pure resolvers are exercised
-- directly since upstream callers only hit a subset of the shapes.
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local choice_support = require("src.ui.view.choice_support")

-- 原生 LuaUnit 迁移(busted → LuaUnit):describe 拍平为 TestChoiceSupport,
-- 断言走 support.assert_eq(actual, expected),用例数与改写前一一对应(2 例)。

TestChoiceSupport = {}

function TestChoiceSupport:test_resolves_option_ids_labels_and_lookups_across_shapes()
  _assert_eq(choice_support.resolve_option_id({ id = 5 }), 5, "table option resolves its id")
  _assert_eq(choice_support.resolve_option_id("scalar"), "scalar", "scalar option resolves to itself")

  _assert_eq(choice_support.resolve_option_label({ label = "L" }), "L", "table label wins")
  _assert_eq(choice_support.resolve_option_label({ id = 7 }), "7", "id falls back to its string")
  _assert_eq(choice_support.resolve_option_label("z"), "z", "scalar label is its string")

  local choice = { options = { { id = 1, label = "one" }, { id = 2, label = "two" } } }
  _assert_eq(choice_support.resolve_option_by_id(nil, 1), nil, "nil choice resolves to nil")
  _assert_eq(choice_support.resolve_option_by_id(choice, nil), nil, "nil id resolves to nil")
  _assert_eq(choice_support.resolve_option_by_id({ options = "bad" }, 1), nil, "non-table options resolve to nil")
  _assert_eq(choice_support.resolve_option_by_id(choice, 2).label, "two", "matching id returns its option")
  _assert_eq(choice_support.resolve_option_by_id(choice, 9), nil, "missing id resolves to nil")

  _assert_eq(choice_support.resolve_option_label_by_id(choice, 1), "one", "label-by-id returns table label")
  _assert_eq(choice_support.resolve_option_label_by_id(choice, 9), nil, "missing id label resolves to nil")
  _assert_eq(choice_support.resolve_option_label_by_id({ options = { 3 } }, 3), "3",
    "scalar option falls back to the matched id string")
end

function TestChoiceSupport:test_secondary_confirm_body_falls_back_through_option_and_choice_text()
  _assert_eq(choice_support.resolve_secondary_confirm_body(nil, nil, nil, nil, ""),
    "请再确认一次", "no choice and empty label uses the generic fallback")
  _assert_eq(choice_support.resolve_secondary_confirm_body(nil, nil, nil, nil, "金牌"),
    "你选的是：金牌", "no choice with a label echoes the label")

  local choice = { options = { { id = 1, confirm_body = "确认买入" } }, confirm_body = "通用确认" }
  _assert_eq(choice_support.resolve_secondary_confirm_body(choice, nil, nil, 1), "确认买入",
    "option confirm_body wins when present")
  _assert_eq(choice_support.resolve_secondary_confirm_body({ confirm_body = "通用确认" }, nil, nil, 1),
    "通用确认", "choice confirm_body is the next fallback")
end


return TestChoiceSupport
