local market_view = require("src.ui.render.market")
local canvas = require("src.ui.ctl.canvas_coordinator")
local with_client_role = require("src.core.utils.with_client_role")
local runtime = require("src.ui.render.runtime_ui")
local role_context = require("src.ui.pres.role_context")
local runtime_state = require("src.ui.runtime.state")

local renderer = {}

local function _view_deps()
  return {
    runtime = runtime,
    modal_state = require("src.ui.stores.modal_state"),
  }
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

function renderer.open(state, choice, choice_id, market)
  return renderer.open_market_panel(state, choice, choice_id, market)
end

function renderer.close_market_panel(state)
  market_view.close_market_panel(state, _view_deps())
end

function renderer.close(state)
  return renderer.close_market_panel(state)
end

function renderer.select_market_option(state, option_id)
  market_view.select_market_option(state, option_id, _view_deps())
end

function renderer.select_option(state, option_id)
  return renderer.select_market_option(state, option_id)
end

return renderer
