local market_view = require("src.presentation.render.market_view")
local canvas = require("src.presentation.interaction.ui_canvas_coordinator")
local runtime = require("src.presentation.adapter.ui_runtime_port")
local role_context = require("src.presentation.state.ui_role_context")
local runtime_state = require("src.core.runtime_facade.runtime_state")

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
    end)
  end)
  runtime.set_client_role(nil)
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
  ui.market_active = market_view.refresh_market(state, market_payload) == true
end

function renderer.close_market_panel(state)
  market_view.close_market_panel(state)
end

return renderer
