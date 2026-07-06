local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local ui_touch_policy_runtime = require("src.ui.input.touch")
local panel_interrupt = require("src.ui.coord.panel_interrupt")
local panel_action_controls = require("src.ui.render.widgets.panel_action_controls")

local panel_controls = {}

panel_controls.apply_countdown = panel_action_controls.apply_countdown
panel_controls.apply_action_hint = panel_action_controls.apply_action_hint
panel_controls.apply_base_action_controls = panel_action_controls.apply_base_action_controls

local function _set_visible_many(ui, names, visible)
  for _, name in ipairs(names or {}) do
    ui:set_visible(name, visible)
  end
end

function panel_controls.apply_base_non_player_visibility(ui, visible)
  assert(ui ~= nil, "missing ui")
  local value = visible == true
  _set_visible_many(ui, ui.base_hidden_nodes, value)
  _set_visible_many(ui, ui.base_hidden_labels, value)
end

local function _resolve_auto_label(panel, display_player_id)
  if panel == nil then
    return nil
  end
  local labels_by_player = panel.auto_label_by_player
  if labels_by_player ~= nil and display_player_id ~= nil then
    local auto_label = labels_by_player[display_player_id]
    if auto_label then
      return auto_label
    end
  end
  return panel.auto_label
end

local function _apply_auto_label(ui, panel, display_player_id)
  local auto_label = _resolve_auto_label(panel, display_player_id)
  if auto_label == nil or not ui.set_label then
    return
  end
  ui:set_label(base_nodes.auto_label, auto_label)
end

local function _show_auto_controls(ui, controls)
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
  end
end

local function _resolve_auto_controls(ui)
  return ui.auto_control_nodes or { base_nodes.auto_button, base_nodes.auto_label }
end

local function _is_player_role(ctx)
  return ctx.is_player_role == true
end

function panel_controls.render_auto_controls_for_role(ui, ctx, ui_model, ui_touch_policy)
  assert(ui ~= nil, "missing ui")
  local controls = _resolve_auto_controls(ui)
  local panel = ui_model and ui_model.panel or nil
  _apply_auto_label(ui, panel, ctx.display_player_id)
  _show_auto_controls(ui, controls)
  ui_touch_policy.set_auto_controls_touch(ui, _is_player_role(ctx), controls)
end

function panel_controls.is_base_non_player_visible(ui, ctx)
  if ui.input_blocked then
    return false
  end
  if panel_interrupt.settlement_type(ui) ~= nil then
    return false
  end
  return ctx.can_operate == true
end

local function _auto_effect_role_id(ctx)
  if ctx.is_player_role ~= true then
    return nil
  end
  return ctx.role_id
end

local function _resolve_auto_effect_visible(ui_model, ctx)
  local role_id = _auto_effect_role_id(ctx)
  if role_id == nil then return false end
  local auto_by_player = ui_model.auto_enabled_by_player or {}
  return role_id_utils.read(auto_by_player, role_id) == true
end

function panel_controls.apply_auto_effect(ui, ui_model, ctx)
  ui:set_visible(base_nodes.auto_effect, _resolve_auto_effect_visible(ui_model, ctx))
  ui:set_touch_enabled(base_nodes.auto_effect, false)
end

function panel_controls.resolve_skin_entry_visible(ui_model, ctx)
  local current_player_id = role_id_utils.normalize(ui_model.current_player_id)
  if current_player_id == nil then
    return false
  end
  return ctx.can_operate ~= true
end

function panel_controls.apply_skin_entry_visibility(ui, visible)
  local value = visible == true
  ui:set_visible(base_nodes.skin_button, value)
  ui:set_visible(base_nodes.skin_label, value)
  ui:set_touch_enabled(base_nodes.skin_button, value)
  ui:set_touch_enabled(base_nodes.skin_label, false)
  ui_touch_policy_runtime.set_many_touch_enabled(ui, base_nodes.skin_effect_nodes, false)
end

return panel_controls

--[[ mutate4lua-manifest
version=2
projectHash=53da85fa3a003eaa
scope.0.id=chunk:src/ui/render/widgets/panel_controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=118
scope.0.semanticHash=da6512037e829e80
scope.1.id=function:panel_controls.apply_base_non_player_visibility:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=24
scope.1.semanticHash=ef6de9bca4dc5057
scope.2.id=function:_resolve_auto_label:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=38
scope.2.semanticHash=345047a32f2e537e
scope.3.id=function:_apply_auto_label:40
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=46
scope.3.semanticHash=e150ea2cd88c88ec
scope.4.id=function:_resolve_auto_controls:54
scope.4.kind=function
scope.4.startLine=54
scope.4.endLine=56
scope.4.semanticHash=d09a451dac757585
scope.5.id=function:_is_player_role:58
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=60
scope.5.semanticHash=11fa5f0f413d43c6
scope.6.id=function:panel_controls.render_auto_controls_for_role:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=69
scope.6.semanticHash=f58cbd8969aca74e
scope.7.id=function:panel_controls.is_base_non_player_visible:71
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=79
scope.7.semanticHash=e7753dc5b0555ffe
scope.8.id=function:_auto_effect_role_id:81
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=86
scope.8.semanticHash=650eaefacab9d2c1
scope.9.id=function:_resolve_auto_effect_visible:88
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=93
scope.9.semanticHash=810d1a8f5b1b41bf
scope.10.id=function:panel_controls.apply_auto_effect:95
scope.10.kind=function
scope.10.startLine=95
scope.10.endLine=98
scope.10.semanticHash=bb3382a6f5052c9b
scope.11.id=function:panel_controls.resolve_skin_entry_visible:100
scope.11.kind=function
scope.11.startLine=100
scope.11.endLine=106
scope.11.semanticHash=3d15ebc978592446
scope.12.id=function:panel_controls.apply_skin_entry_visibility:108
scope.12.kind=function
scope.12.startLine=108
scope.12.endLine=115
scope.12.semanticHash=901f54f4c9d42dff
]]
