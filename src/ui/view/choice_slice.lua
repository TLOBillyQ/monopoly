local choice_view = require("src.ui.view.choice_builder")
local runtime_state = require("src.ui.state.runtime")

local choice_slice = {}

local function _normalize_market_tab(active_tab)
  if active_tab == "item" then
    return active_tab
  end
  return "item"
end

local function _build_market_view(choice, ui_runtime)
  return {
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

local function _pending_choice(game)
  return game.turn and game.turn.pending_choice
end

local function _build_choice(game, env)
  local pending = _pending_choice(game)
  if pending then
    return choice_view.build_choice_view(pending, { game = env.game })
  end
  return nil
end

local function _build_market_if_needed(choice, ui_runtime)
  if choice and choice.route_key == "market" then
    return _build_market_view(choice, ui_runtime)
  end
  return nil
end

function choice_slice.build_choice_and_market(game, env, ui_state)
  local choice = _build_choice(game, env)
  local ui_runtime = ui_state and runtime_state.ensure_ui_runtime(ui_state) or nil
  local market = _build_market_if_needed(choice, ui_runtime)
  return choice, market
end

return choice_slice

--[[ mutate4lua-manifest
version=4
projectHash=d553ad8792178839
scope.0.id=chunk:src/ui/view/choice_slice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=7aae54f3cc0b3cd6
scope.1.id=function:_normalize_market_tab
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=9f32fb0a8640145d
scope.2.id=function:_build_market_view
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=24
scope.2.semanticHash=384a1f7e8936d06b
scope.3.id=function:_pending_choice
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=294045d18cfbedc1
scope.4.id=function:_build_choice
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=36
scope.4.semanticHash=bd760458d20b5831
scope.5.id=function:_build_market_if_needed
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=43
scope.5.semanticHash=8c8ba47e75f26a71
scope.6.id=function:choice_slice.build_choice_and_market
scope.6.kind=function
scope.6.startLine=45
scope.6.endLine=50
scope.6.semanticHash=5e589b4a1ebfaba5
]]
