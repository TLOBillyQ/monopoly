-- Behavior specs for src/ui/view/choice_slice.lua 的 market 视图构建:
-- active_tab 归一化契约与 pending_choice_selected_option_id 的透传。

local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local choice_slice = require("src.ui.view.choice_slice")

local function _game_with_market_choice(active_tab)
  return {
    turn = {
      pending_choice = {
        id = "c_1",
        kind = "market",
        route_key = "market",
        options = {},
        active_tab = active_tab,
      },
    },
  }
end

local function _ui_state_with_selection(selected)
  return {
    ui_runtime = {
      pending_choice_selected_option_id = selected,
    },
  }
end

TestChoiceSlice = {}

function TestChoiceSlice:test_market_view_normalizes_active_tab_to_item()
  -- 杀 L7 "item"->nil:非 item 与缺省 tab 都归一为 "item"。
  local _, market = choice_slice.build_choice_and_market(
    _game_with_market_choice("skins"),
    {},
    _ui_state_with_selection(nil)
  )
  _assert_eq(market ~= nil, true, "market choice should build a market view")
  _assert_eq(market.active_tab, "item", "non-item tab should normalize to item")

  _, market = choice_slice.build_choice_and_market(
    _game_with_market_choice("item"),
    {},
    _ui_state_with_selection(nil)
  )
  _assert_eq(market.active_tab, "item", "item tab should pass through")

  -- 杀 L7 "item"->nil:active_tab=nil 输入时变异 `if active_tab == nil then
  -- return active_tab` 会返回 nil,而基线经兜底返回 "item"。
  _, market = choice_slice.build_choice_and_market(
    _game_with_market_choice(nil),
    {},
    _ui_state_with_selection(nil)
  )
  _assert_eq(market.active_tab, "item", "missing tab should normalize to item")
end

function TestChoiceSlice:test_market_view_passes_selected_option_id_through()
  -- 杀 L19 两个 or 位点与 L47 ensure_ui_runtime() -> nil / or->and:
  -- 选中项 id 必须从 ui_runtime 透传到 market 视图,不能变 nil 或整表。
  local _, market = choice_slice.build_choice_and_market(
    _game_with_market_choice("item"),
    {},
    _ui_state_with_selection(5)
  )
  _assert_eq(market.selected_option_id, 5,
    "selected option id should pass through the ui_runtime")
end

function TestChoiceSlice:test_market_view_without_ui_state_keeps_selection_nil()
  -- 无 ui_state 时 selected_option_id 必须为 nil(不报错)。
  local _, market = choice_slice.build_choice_and_market(
    _game_with_market_choice("item"),
    {},
    nil
  )
  _assert_eq(market.selected_option_id, nil,
    "missing ui_state should leave the selection nil")
end

return TestChoiceSlice
