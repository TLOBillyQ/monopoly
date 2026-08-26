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

-- Which of 行动 / 结束 owns an optional-action choice depends on the phase the
-- choice sits in: pre-action skips belong to 行动 (they precede the roll),
-- everything else resolves through 结束; a forced choice offers no way out.
local function _optional_action_visibility(choice)
  if not choice_support.is_optional_action_choice(choice) then
    return true, false, false
  end
  if not choice_support.is_cancelable_optional_action_choice(choice) then
    return false, false, false
  end
  if choice_support.is_pre_action_item_phase_passive(choice) then
    return true, false, false
  end
  return false, true, false
end

local function _resolve_base_action_visibility(ui_model, base_visible, cancel_allowed)
  local choice = ui_model and ui_model.choice
  -- Item usage follow-up (道具使用后续选择, kind varies per card, truth source is
  -- rules' meta.passive_origin): the base cancel button is the ONLY exit back to
  -- the item phase window without consuming the card. The follow-up's own screen
  -- sets choice_active, which drops base_visible for the whole base screen, so
  -- the cancel button runs on its own narrow gate (cancel_allowed, computed by
  -- panel_controls.is_base_cancel_allowed: every interruption EXCEPT the choice
  -- itself still blocks). is_base_cancel_choice is the same gate route_base
  -- builds the cancel intent from: 按钮亮即有 intent。
  if choice_support.is_item_target_selection_choice(choice) then
    return false, false, cancel_allowed == true and choice_support.is_base_cancel_choice(choice)
  end
  if base_visible ~= true then
    return false, false, false
  end
  return _optional_action_visibility(choice)
end

function panel_action_controls.apply_base_action_controls(ui, ui_model, base_visible, cancel_allowed)
  local action_visible, end_visible, cancel_visible =
    _resolve_base_action_visibility(ui_model, base_visible, cancel_allowed)
  ui:set_visible(base_nodes.action_button, action_visible)
  ui:set_touch_enabled(base_nodes.action_button, action_visible)
  ui:set_visible(base_nodes.end_button, end_visible)
  ui:set_touch_enabled(base_nodes.end_button, end_visible)
  ui:set_visible(base_nodes.cancel_button, cancel_visible)
  ui:set_touch_enabled(base_nodes.cancel_button, cancel_visible)
end

return panel_action_controls

--[[ mutate4lua-manifest
version=4
projectHash=90b58d4d8901319a
scope.0.id=chunk:src/ui/render/widgets/panel_action_controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=73
scope.0.semanticHash=c0e9f284683f9caa
scope.1.id=function:_resolve_countdown_visible
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=bc2b07c664c5e50a
scope.2.id=function:panel_action_controls.apply_countdown
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=18
scope.2.semanticHash=0e5a8fb8864304f0
scope.3.id=function:panel_action_controls.apply_action_hint
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=24
scope.3.semanticHash=d0397bb5b434860c
scope.4.id=function:_optional_action_visibility
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=40
scope.4.semanticHash=06c38e148b3f8aeb
scope.5.id=function:_resolve_base_action_visibility
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=59
scope.5.semanticHash=5e763b12fbe73d9d
scope.6.id=function:panel_action_controls.apply_base_action_controls
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=70
scope.6.semanticHash=6be5be18e4e7f178
]]
