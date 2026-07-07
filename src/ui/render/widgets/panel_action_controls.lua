local base_nodes = require("src.ui.schema.base")
local choice_support = require("src.ui.view.choice_support")

local panel_action_controls = {}

local function _resolve_countdown_visible(panel)
  if panel and panel.countdown_visible ~= nil then
    return panel.countdown_visible == true
  end
  return true
end

function panel_action_controls.apply_countdown(ui, panel)
  local visible = _resolve_countdown_visible(panel)
  ui:set_visible(base_nodes.countdown, visible)
  ui:set_visible(base_nodes.countdown_line, visible)
  ui:set_label(base_nodes.countdown, panel.turn_label or "")
end

function panel_action_controls.apply_action_hint(ui, panel)
  if panel.no_action_visible == true then
    ui:set_visible(base_nodes.action_hint, true)
  end
end

local function _is_item_target_selection(choice)
  return choice and choice.kind == "item_phase_passive" and choice.meta and choice.meta.passive_origin == true
end

local function _resolve_base_action_visibility(ui_model, base_visible)
  if base_visible ~= true then
    return false, false, false
  end
  local choice = ui_model and ui_model.choice
  if not choice_support.is_optional_action_choice(choice) then
    return true, false, false
  end
  if not choice_support.is_cancelable_optional_action_choice(choice) then
    return false, false, false
  end
  if _is_item_target_selection(choice) then
    return false, false, true
  end
  if choice_support.is_pre_action_item_phase_choice(choice) then
    return true, false, false
  end
  return false, true, false
end

function panel_action_controls.apply_base_action_controls(ui, ui_model, base_visible)
  local action_visible, end_visible, cancel_visible = _resolve_base_action_visibility(ui_model, base_visible)
  ui:set_visible(base_nodes.action_button, action_visible)
  ui:set_touch_enabled(base_nodes.action_button, action_visible)
  ui:set_visible(base_nodes.end_button, end_visible)
  ui:set_touch_enabled(base_nodes.end_button, end_visible)
  ui:set_visible(base_nodes.cancel_button, cancel_visible)
  ui:set_touch_enabled(base_nodes.cancel_button, cancel_visible)
end

return panel_action_controls

--[[ mutate4lua-manifest
version=2
projectHash=afae6d37b56bf54a
scope.0.id=chunk:src/ui/render/widgets/panel_action_controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=58
scope.0.semanticHash=5527abc12da0eae7
scope.1.id=function:_resolve_countdown_visible:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=d138d75db44c8e79
scope.2.id=function:panel_action_controls.apply_countdown:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=18
scope.2.semanticHash=a69ab5f2d96a7488
scope.3.id=function:panel_action_controls.apply_action_hint:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=24
scope.3.semanticHash=f0f7b526718bfd27
scope.4.id=function:_is_item_target_selection:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=4fac194c58cedb6e
scope.5.id=function:_resolve_base_action_visibility:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=45
scope.5.semanticHash=c00fa97b201f8797
scope.6.id=function:panel_action_controls.apply_base_action_controls:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=55
scope.6.semanticHash=d74cc2e3a1a8f338
]]
