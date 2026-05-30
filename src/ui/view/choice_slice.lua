local choice_view = require("src.ui.view.choice_builder")
local runtime_state = require("src.ui.state.runtime")

local choice_slice = {}

local function _normalize_market_tab(active_tab)
  if active_tab == "item" then
    return active_tab
  end
  return "item"
end

function choice_slice.build_choice_and_market(game, env, ui_state)
  local choice = nil
  local pending = game.turn and game.turn.pending_choice
  if pending then
    choice = choice_view.build_choice_view(pending, { game = env.game })
  end
  local market = nil
  local ui_runtime = ui_state and runtime_state.ensure_ui_runtime(ui_state) or nil
  if choice and choice.route_key == "market" then
    market = {
      choice_id = choice.id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = ui_runtime and ui_runtime.pending_choice_selected_option_id or nil,
      active_tab = _normalize_market_tab(choice.active_tab),
      page_index = choice.page_index,
      page_count = choice.page_count,
    }
  end
  return choice, market
end

return choice_slice

--[[ mutate4lua-manifest
version=2
projectHash=04482f7fc9673731
scope.0.id=chunk:src/ui/view/choice_slice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=1ed50b40e20cd1a1
scope.1.id=function:_normalize_market_tab:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=651f79777822e647
scope.2.id=function:choice_slice.build_choice_and_market:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=34
scope.2.semanticHash=abc16a60b76bae38
]]
