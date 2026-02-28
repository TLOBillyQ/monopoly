local market_view = require("src.presentation.render.MarketView")
local base_presenter = require("src.presentation.canvas.base.presenter")
local render_pipeline = require("src.presentation.canvas_runtime.CanvasRenderPipeline")
local input_lock_policy = require("src.presentation.interaction.UIInputLockPolicy")
local role_control_lock_policy = require("src.presentation.interaction.UIRoleControlLockPolicy")
local modal_presenter = require("src.presentation.ui.UIModalPresenter")
local logger = require("src.core.Logger")

local state = require("src.presentation.api.ui_view_service.state")
local assets = require("src.presentation.api.ui_view_service.assets")
local item_slots = require("src.presentation.api.ui_view_service.item_slots")
local debug = require("src.presentation.api.ui_view_service.debug")

local service = {}

function service.build_ui_state()
  return state.build_ui_state()
end

function service.init_ui_assets(ui_state)
  assets.init_ui_assets(ui_state)
end

function service.capture_player_colors(ui_state, game)
  assets.capture_player_colors(ui_state, game)
end

function service.refresh_panel(state_ctx, ui_model)
  base_presenter.refresh(state_ctx, ui_model, {
    runtime = require("src.presentation.api.UIRuntimePort"),
    refresh_item_slots = service.refresh_item_slots,
  })
end

function service.refresh_turn_label(state_ctx, label_text)
  local ui = state_ctx.ui
  if not ui or not ui.set_label then
    return
  end
  local runtime = require("src.presentation.api.UIRuntimePort")
  runtime.for_each_role_or_global(function()
    ui:set_label(require("src.presentation.canvas.base.nodes").countdown, label_text)
  end)
  runtime.set_client_role(nil)
end

function service.refresh_item_slots(state_ctx, ui_model, opts)
  item_slots.refresh_item_slots(state_ctx, ui_model, opts)
end

function service.apply_input_lock(state_ctx)
  input_lock_policy.apply(state_ctx, { runtime = require("src.presentation.api.UIRuntimePort") })
end

function service.apply_role_control_lock(state_ctx, enabled)
  role_control_lock_policy.sync(state_ctx, enabled, { runtime = require("src.presentation.api.UIRuntimePort") })
end

function service.render(state_ctx, ui_model, log_once, build_log_prefix)
  render_pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, {
    runtime = require("src.presentation.api.UIRuntimePort"),
    refresh_item_slots = service.refresh_item_slots,
  })
end

function service.set_debug_log(state_ctx, text)
  debug.set_debug_log(state_ctx, text)
end

function service.set_debug_visible(state_ctx, visible)
  debug.set_debug_visible(state_ctx, visible)
end

function service.select_market_option(state_ctx, option_id)
  if not option_id then
    logger.warn("select_market_option missing option_id")
    return
  end
  market_view.select_market_option(state_ctx, option_id)
end

function service.select_choice_option(state_ctx, option_id)
  if not option_id then
    logger.warn("select_choice_option missing option_id")
    return
  end
  modal_presenter.select_choice_option(state_ctx, option_id)
end

function service.open_choice_modal(state_ctx, choice, market)
  modal_presenter.open_choice_modal(state_ctx, choice, market)
end

function service.close_choice_modal(state_ctx)
  modal_presenter.close_choice_modal(state_ctx)
end

function service.push_popup(state_ctx, payload)
  return modal_presenter.push_popup(state_ctx, payload)
end

function service.close_popup(state_ctx)
  modal_presenter.close_popup(state_ctx)
end

return service
