local market_view = require("src.presentation.render.MarketView")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local runtime = require("src.presentation.api.UIRuntimePort")
local role_context = require("src.presentation.state.UIRoleContext")

local renderer = {}

local function _with_client_role(role, fn)
  if type(runtime.with_client_role) == "function" then
    return runtime.with_client_role(role, fn)
  end
  runtime.set_client_role(role)
  local ok, err = pcall(fn)
  runtime.set_client_role(nil)
  if not ok then
    error(err)
  end
end

function renderer.open_market_panel(state, choice, choice_id, market)
  local ui = state.ui
  runtime.for_each_role_or_global(function(role)
    _with_client_role(role, function()
      local ctx = role_context.resolve(role, state.ui_model, { runtime = runtime })
      local target = canvas.CANVAS_BASE
      if ctx.can_operate == true then
        target = canvas.CANVAS_MARKET
      end
      if role then
        canvas.switch_for_role(ui, target, role)
      else
        canvas.switch(ui, target)
      end
    end)
  end)
  runtime.set_client_role(nil)
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = state.pending_choice_selected_option_id,
    active_tab = choice.active_tab,
    page_index = choice.page_index,
    page_count = choice.page_count,
  }
  ui.market_active = market_view.refresh_market(state, market_payload) == true
end

function renderer.close_market_panel(state)
  market_view.close_market_panel(state)
end

return renderer
