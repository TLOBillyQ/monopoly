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
  -- Item target selection opens a dedicated target screen with its own cancel,
  -- so the base screen hides all three main buttons during target selection.
  if choice_support.is_item_target_selection_choice(choice) then
    return false, false, false
  end
  if choice_support.is_pre_action_item_phase_choice(choice) then
    return true, false, false
  end
  -- The base cancel button belongs to the item phase (道具阶段) and backs out of
  -- item usage on the base screen without consuming the card.
  if choice_support.is_item_usage_phase_choice(choice) then
    return false, false, true
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
projectHash=d2e63b62a347c9e0
scope.0.id=chunk:src/ui/render/widgets/panel_action_controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=64
scope.0.semanticHash=77a0365a5afee15d
scope.0.lastMutatedAt=2026-07-07T08:27:30Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:_resolve_countdown_visible:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=d138d75db44c8e79
scope.1.lastMutatedAt=2026-07-07T08:27:30Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:panel_action_controls.apply_countdown:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=18
scope.2.semanticHash=a69ab5f2d96a7488
scope.2.lastMutatedAt=2026-07-07T08:27:30Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:panel_action_controls.apply_action_hint:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=24
scope.3.semanticHash=f0f7b526718bfd27
scope.3.lastMutatedAt=2026-07-07T08:27:30Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_resolve_base_action_visibility:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=51
scope.4.semanticHash=6cced4b20cb0605b
scope.4.lastMutatedAt=2026-07-07T08:27:30Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=31
scope.4.lastMutationKilled=31
scope.5.id=function:panel_action_controls.apply_base_action_controls:53
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=61
scope.5.semanticHash=d74cc2e3a1a8f338
scope.5.lastMutatedAt=2026-07-07T08:27:30Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=7
]]
