local nodes = require("src.ui.schema.skin")

local M = {}

local function _set_optional_ui_value(ui, method_name, node_name, value)
  if value == nil then
    return
  end
  local setter = ui[method_name]
  if setter then
    setter(ui, node_name, value)
  end
end

function M.refresh_button(ui, slot, view)
  local button_name = nodes.action_buttons[slot]
  if not button_name then
    return
  end
  view = view or {}
  _set_optional_ui_value(ui, "set_button", button_name, view.button_text)
  _set_optional_ui_value(ui, "set_visible", button_name, view.has_skin == true)
  _set_optional_ui_value(ui, "set_touch_enabled", button_name, view.button_touch_enabled)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=22563e585e0241c8
scope.0.id=chunk:src/ui/render/skin_panel_buttons.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=72
scope.0.semanticHash=33d93f86b6412322
scope.0.lastMutatedAt=2026-06-24T20:14:41Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:_button_text_for_locked:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=13
scope.1.semanticHash=5d5b20a0f84e58d5
scope.1.lastMutatedAt=2026-06-24T20:14:41Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_button_props:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=30
scope.2.semanticHash=a07918254914166b
scope.2.lastMutatedAt=2026-06-24T20:14:41Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_set_optional_ui_value:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=40
scope.3.semanticHash=23a3af7fdb9d091c
scope.3.lastMutatedAt=2026-06-24T20:14:41Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:M.slot_state:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=57
scope.4.semanticHash=87ed06ba9c40a6f8
scope.4.lastMutatedAt=2026-06-24T20:14:41Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=13
scope.4.lastMutationKilled=13
scope.5.id=function:M.refresh_button:59
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=69
scope.5.semanticHash=6e9c8b7f742b2e1f
scope.5.lastMutatedAt=2026-06-24T20:14:41Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
]]
