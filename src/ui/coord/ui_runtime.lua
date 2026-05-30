local panel_presenter = require("src.ui.render.widgets.presenter")
local render_pipeline = require("src.ui.render.render_pipeline")
local input_lock_policy = require("src.ui.input.lock")
local role_control_lock_policy = require("src.ui.input.role_control_lock")
local ui_touch_policy = require("src.ui.input.touch")
local runtime = require("src.ui.render.runtime_ui")
local schema_base_nodes = require("src.ui.schema.base")

local state = require("src.ui.coord.ui_state")
local assets = require("src.ui.render.assets")
local item_slots = require("src.ui.coord.item_slots")
local event_log_view = require("src.ui.coord.event_log_view")

local service = {}

local _render_opts = {
  runtime = runtime,
  refresh_item_slots = nil,
  ui_touch_policy = ui_touch_policy,
}
local _input_lock_opts = { runtime = runtime }
local _role_control_opts = { runtime = runtime }

local turn_label_refresh_context = {
  ui = nil,
  base_nodes = nil,
  label_text = nil,
  countdown_visible = nil,
}

service.build_ui_state = state.build_ui_state
service.init_ui_assets = assets.init_ui_assets
service.capture_player_colors = assets.capture_player_colors

function service.refresh_panel(state_ctx, ui_model)
  _render_opts.refresh_item_slots = service.refresh_item_slots
  panel_presenter.refresh(state_ctx, ui_model, _render_opts)
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

local function _refresh_turn_label_for_client_role()
  local ui = turn_label_refresh_context.ui
  local base_nodes = turn_label_refresh_context.base_nodes
  local label_text = turn_label_refresh_context.label_text
  local countdown_visible = turn_label_refresh_context.countdown_visible
  if ui ~= nil and base_nodes ~= nil then
    _refresh_turn_label_for_runtime_role(ui, base_nodes, label_text, countdown_visible)
  end
end

local function _clear_turn_label_refresh_context()
  turn_label_refresh_context.ui = nil
  turn_label_refresh_context.base_nodes = nil
  turn_label_refresh_context.label_text = nil
  turn_label_refresh_context.countdown_visible = nil
end

function service.refresh_turn_label(state_ctx, label_text, visible)
  local ui = state_ctx.ui
  if not ui then
    return
  end
  local countdown_visible = visible ~= false

  turn_label_refresh_context.ui = ui
  turn_label_refresh_context.base_nodes = schema_base_nodes
  turn_label_refresh_context.label_text = label_text
  turn_label_refresh_context.countdown_visible = countdown_visible

  runtime.for_each_role_or_global(_refresh_turn_label_for_client_role)

  _clear_turn_label_refresh_context()
  runtime.set_client_role(nil)
end

service.refresh_item_slots = item_slots.refresh_item_slots

function service.apply_input_lock(state_ctx)
  input_lock_policy.apply(state_ctx, _input_lock_opts)
end

function service.apply_role_control_lock(state_ctx, enabled)
  role_control_lock_policy.sync(state_ctx, enabled, _role_control_opts)
end

function service.render(state_ctx, ui_model, log_once, build_log_prefix)
  _render_opts.refresh_item_slots = service.refresh_item_slots
  render_pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, _render_opts)
end

service.set_event_log = event_log_view.set_event_log
service.set_event_log_visible = event_log_view.set_event_log_visible
service.set_event_log_visible_for_role = event_log_view.set_event_log_visible_for_role
service.set_event_log_for_role = event_log_view.set_event_log_for_role

return service

--[[ mutate4lua-manifest
version=2
projectHash=78ffbfbd7e02dbd9
scope.0.id=chunk:src/ui/coord/ui_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=106
scope.0.semanticHash=e14f7923b59c1a81
scope.1.id=function:service.refresh_panel:35
scope.1.kind=function
scope.1.startLine=35
scope.1.endLine=38
scope.1.semanticHash=363d7fda5a79c02f
scope.2.id=function:_refresh_turn_label_for_runtime_role:40
scope.2.kind=function
scope.2.startLine=40
scope.2.endLine=48
scope.2.semanticHash=77e94eb8154271ac
scope.3.id=function:_refresh_turn_label_for_client_role:50
scope.3.kind=function
scope.3.startLine=50
scope.3.endLine=58
scope.3.semanticHash=336e973ea7ce56e1
scope.4.id=function:_clear_turn_label_refresh_context:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=65
scope.4.semanticHash=cbe6cce48a935839
scope.5.id=function:service.refresh_turn_label:67
scope.5.kind=function
scope.5.startLine=67
scope.5.endLine=83
scope.5.semanticHash=0e0235be6f4648fe
scope.6.id=function:service.apply_input_lock:87
scope.6.kind=function
scope.6.startLine=87
scope.6.endLine=89
scope.6.semanticHash=1ea4c30d0f082ec1
scope.7.id=function:service.apply_role_control_lock:91
scope.7.kind=function
scope.7.startLine=91
scope.7.endLine=93
scope.7.semanticHash=5a150d3727e2e100
scope.8.id=function:service.render:95
scope.8.kind=function
scope.8.startLine=95
scope.8.endLine=98
scope.8.semanticHash=8eda8d9fdbf95cf2
]]
