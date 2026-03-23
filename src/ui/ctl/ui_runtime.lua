local panel_presenter = require("src.ui.wid.panel_presenter")
local render_pipeline = require("src.ui.render.canvas_render_pipeline")
local input_lock_policy = require("src.ui.input.lock_policy")
local role_control_lock_policy = require("src.ui.input.role_control_lock_policy")
local ui_touch_policy = require("src.ui.input.touch_policy")
local runtime = require("src.ui.render.runtime_ui")

local state = require("src.ui.ctl.ui_state")
local assets = require("src.ui.render.ui_assets")
local item_slots = require("src.ui.ctl.item_slots")
local debug = require("src.ui.ctl.debug_view")

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
  panel_presenter.refresh(state_ctx, ui_model, {
    runtime = runtime,
    refresh_item_slots = service.refresh_item_slots,
    ui_touch_policy = ui_touch_policy,
  })
end

local function _refresh_turn_label_for_runtime_role(ui, base_nodes, label_text, countdown_visible)
  if ui.set_visible then
    ui:set_visible(base_nodes.countdown, countdown_visible)
    ui:set_visible(base_nodes.countdown_line, countdown_visible)
  end
  if ui.set_label then
    ui:set_label(base_nodes.countdown, label_text)
  end
end

function service.refresh_turn_label(state_ctx, label_text, visible)
  local ui = state_ctx.ui
  if not ui then
    return
  end
  local base_nodes = require("src.ui.schema.base_nodes")
  local countdown_visible = visible ~= false
  runtime.for_each_role_or_global(function()
    _refresh_turn_label_for_runtime_role(ui, base_nodes, label_text, countdown_visible)
  end)
  runtime.set_client_role(nil)
end

function service.refresh_item_slots(state_ctx, ui_model, opts)
  item_slots.refresh_item_slots(state_ctx, ui_model, opts)
end

function service.apply_input_lock(state_ctx)
  input_lock_policy.apply(state_ctx, { runtime = runtime })
end

function service.apply_role_control_lock(state_ctx, enabled)
  role_control_lock_policy.sync(state_ctx, enabled, { runtime = runtime })
end

function service.render(state_ctx, ui_model, log_once, build_log_prefix)
  render_pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, {
    runtime = runtime,
    refresh_item_slots = service.refresh_item_slots,
    ui_touch_policy = ui_touch_policy,
  })
end

function service.set_debug_log(state_ctx, text)
  debug.set_debug_log(state_ctx, text)
end

function service.set_debug_visible(state_ctx, visible)
  debug.set_debug_visible(state_ctx, visible)
end

function service.set_debug_visible_for_role(state_ctx, role, visible)
  return debug.set_debug_visible_for_role(state_ctx, role, visible)
end

function service.set_debug_log_for_role(state_ctx, role, text)
  debug.set_debug_log_for_role(state_ctx, role, text)
end

return service
