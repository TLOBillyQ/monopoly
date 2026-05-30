local market_view = require("src.ui.render.market")
local canvas = require("src.ui.coord.canvas_coordinator")
local with_client_role = require("src.ui.utils.with_client_role")
local runtime = require("src.ui.render.runtime_ui")
local role_context = require("src.ui.view.role_context")
local runtime_state = require("src.ui.state.runtime")
local panel_interrupt = require("src.ui.coord.panel_interrupt")

local renderer = {}

local function _view_deps()
  return {
    runtime = runtime,
    modal_state = require("src.ui.state.modal"),
  }
end

local function _interrupt_panels_before_market_open(state)
  local ui = state and state.ui or nil
  if ui == nil then
    return
  end
  local was_market_active = ui.market_active
  ui.market_active = true
  panel_interrupt.interrupt(state)
  ui.market_active = was_market_active
end

function renderer.open_market_panel(state, choice, choice_id, market)
  local ui = state.ui
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = runtime_state.ensure_ui_runtime(state).pending_choice_selected_option_id,
    active_tab = choice.active_tab,
    page_index = choice.page_index,
    page_count = choice.page_count,
  }
  local opened = false

  _interrupt_panels_before_market_open(state)
  runtime.for_each_role_or_global(function(role)
    with_client_role(runtime, role, function()
      local current_model = runtime_state.get_ui_model(state)
      local ctx = role_context.resolve(role, current_model, { runtime = runtime })
      local target = canvas.CANVAS_BASE
      if ctx.can_operate == true then
        target = canvas.CANVAS_MARKET
      end
      if role then
        canvas.switch_for_role(ui, target, role)
      else
        canvas.switch(ui, target)
      end
      if ctx.can_operate == true then
        opened = market_view.refresh_market(state, market_payload, _view_deps()) == true or opened
      end
    end)
  end)
  runtime.set_client_role(nil)
  ui.market_active = opened
end

renderer.open = renderer.open_market_panel

function renderer.close_market_panel(state)
  market_view.close_market_panel(state, _view_deps())
end

renderer.close = renderer.close_market_panel

function renderer.select_market_option(state, option_id)
  market_view.select_market_option(state, option_id, _view_deps())
end

return renderer

--[[ mutate4lua-manifest
version=2
projectHash=05155d0eee67133e
scope.0.id=chunk:src/ui/coord/market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=1af062ba48d4846e
scope.1.id=function:_view_deps:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=16
scope.1.semanticHash=836adb93dbb703f1
scope.2.id=function:anonymous@33:33
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=48
scope.2.semanticHash=c81e0dfc36133d3b
scope.3.id=function:anonymous@32:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=49
scope.3.semanticHash=04559750a35e1cb3
scope.4.id=function:renderer.open_market_panel:18
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=55
scope.4.semanticHash=1bfec48dd643bcec
scope.5.id=function:renderer.close_market_panel:59
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=61
scope.5.semanticHash=42920bd317d245ab
scope.6.id=function:renderer.select_market_option:65
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=67
scope.6.semanticHash=ff4fec1becd11f93
]]
