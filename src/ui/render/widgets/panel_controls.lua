local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local ui_touch_policy_runtime = require("src.ui.input.touch")
local choice_support = require("src.ui.view.choice_support")

local panel_controls = {}

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

local function _resolve_countdown_visible(panel)
  if panel and panel.countdown_visible ~= nil then
    return panel.countdown_visible == true
  end
  return true
end

function panel_controls.apply_countdown(ui, panel)
  local visible = _resolve_countdown_visible(panel)
  ui:set_visible(base_nodes.countdown, visible)
  ui:set_visible(base_nodes.countdown_line, visible)
  ui:set_label(base_nodes.countdown, panel.turn_label or "")
end

function panel_controls.apply_action_hint(ui, panel)
  if panel.no_action_visible == true then
    ui:set_visible(base_nodes.action_hint, true)
  end
end

local function _set_button_label(ui, name, text)
  if ui.set_button then
    ui:set_button(name, text)
    return
  end
  if ui.set_label then
    ui:set_label(name, text)
  end
end

local function _resolve_base_action_visibility(ui_model, base_visible)
  if base_visible ~= true then
    return false, false
  end
  local choice = ui_model and ui_model.choice
  if not choice_support.is_optional_action_choice(choice) then
    return true, false
  end
  return false, choice_support.is_cancelable_optional_action_choice(choice) == true
end

function panel_controls.apply_base_action_controls(ui, ui_model, base_visible)
  local action_visible, end_visible = _resolve_base_action_visibility(ui_model, base_visible)
  ui:set_visible(base_nodes.action_button, action_visible)
  ui:set_touch_enabled(base_nodes.action_button, action_visible)
  ui:set_visible(base_nodes.end_button, end_visible)
  ui:set_touch_enabled(base_nodes.end_button, end_visible)
  if end_visible then
    _set_button_label(ui, base_nodes.end_button, "结束")
  end
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
projectHash=7722a7e9b19dda82
scope.0.id=chunk:src/ui/render/widgets/panel_controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=162
scope.0.semanticHash=d693d429a46b0fcb
scope.0.lastMutatedAt=2026-06-23T04:33:39Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:panel_controls.apply_base_non_player_visibility:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=ef6de9bca4dc5057
scope.1.lastMutatedAt=2026-06-23T03:16:02Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_resolve_auto_label:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=33
scope.2.semanticHash=345047a32f2e537e
scope.2.lastMutatedAt=2026-06-23T03:16:02Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_apply_auto_label:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=41
scope.3.semanticHash=e150ea2cd88c88ec
scope.3.lastMutatedAt=2026-06-23T03:16:02Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:_resolve_auto_controls:49
scope.4.kind=function
scope.4.startLine=49
scope.4.endLine=51
scope.4.semanticHash=d09a451dac757585
scope.4.lastMutatedAt=2026-06-23T03:16:02Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_is_player_role:53
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=55
scope.5.semanticHash=11fa5f0f413d43c6
scope.5.lastMutatedAt=2026-06-23T03:16:02Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:panel_controls.render_auto_controls_for_role:57
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=64
scope.6.semanticHash=f58cbd8969aca74e
scope.6.lastMutatedAt=2026-06-23T03:16:02Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:panel_controls.is_base_non_player_visible:66
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=71
scope.7.semanticHash=71808df79d379da3
scope.7.lastMutatedAt=2026-06-23T03:16:02Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:_auto_effect_role_id:73
scope.8.kind=function
scope.8.startLine=73
scope.8.endLine=78
scope.8.semanticHash=650eaefacab9d2c1
scope.8.lastMutatedAt=2026-06-23T03:16:02Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=2
scope.8.lastMutationKilled=2
scope.9.id=function:_resolve_auto_effect_visible:80
scope.9.kind=function
scope.9.startLine=80
scope.9.endLine=85
scope.9.semanticHash=810d1a8f5b1b41bf
scope.9.lastMutatedAt=2026-06-23T03:16:02Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=7
scope.9.lastMutationKilled=7
scope.10.id=function:panel_controls.apply_auto_effect:87
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=90
scope.10.semanticHash=bb3382a6f5052c9b
scope.10.lastMutatedAt=2026-06-23T03:16:02Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=2
scope.10.lastMutationKilled=2
scope.11.id=function:_resolve_countdown_visible:92
scope.11.kind=function
scope.11.startLine=92
scope.11.endLine=97
scope.11.semanticHash=d138d75db44c8e79
scope.11.lastMutatedAt=2026-06-23T03:16:02Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=5
scope.11.lastMutationKilled=5
scope.12.id=function:panel_controls.apply_countdown:99
scope.12.kind=function
scope.12.startLine=99
scope.12.endLine=104
scope.12.semanticHash=7455c8003c320d33
scope.12.lastMutatedAt=2026-06-23T03:16:02Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=4
scope.12.lastMutationKilled=4
scope.13.id=function:panel_controls.apply_action_hint:106
scope.13.kind=function
scope.13.startLine=106
scope.13.endLine=110
scope.13.semanticHash=cc5654133bb91ba0
scope.13.lastMutatedAt=2026-06-23T03:16:02Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=3
scope.13.lastMutationKilled=3
scope.14.id=function:_set_button_label:112
scope.14.kind=function
scope.14.startLine=112
scope.14.endLine=120
scope.14.semanticHash=949fd0a84e9a5970
scope.14.lastMutatedAt=2026-06-23T03:16:02Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=2
scope.14.lastMutationKilled=2
scope.15.id=function:_resolve_base_action_visibility:122
scope.15.kind=function
scope.15.startLine=122
scope.15.endLine=131
scope.15.semanticHash=b6149251caf74d32
scope.15.lastMutatedAt=2026-06-23T04:33:39Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=13
scope.15.lastMutationKilled=13
scope.16.id=function:panel_controls.apply_base_action_controls:133
scope.16.kind=function
scope.16.startLine=133
scope.16.endLine=142
scope.16.semanticHash=e709094a1f8de4d2
scope.16.lastMutatedAt=2026-06-23T04:33:39Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=6
scope.16.lastMutationKilled=6
scope.17.id=function:panel_controls.resolve_skin_entry_visible:144
scope.17.kind=function
scope.17.startLine=144
scope.17.endLine=150
scope.17.semanticHash=3d15ebc978592446
scope.17.lastMutatedAt=2026-06-23T04:33:39Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=5
scope.17.lastMutationKilled=5
scope.18.id=function:panel_controls.apply_skin_entry_visibility:152
scope.18.kind=function
scope.18.startLine=152
scope.18.endLine=159
scope.18.semanticHash=901f54f4c9d42dff
scope.18.lastMutatedAt=2026-06-23T04:33:39Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=7
scope.18.lastMutationKilled=7
]]
