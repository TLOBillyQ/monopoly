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
version=4
projectHash=85e55bc9066f29d1
scope.0.id=chunk:src/ui/render/widgets/skin_panel_buttons.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=27
scope.0.semanticHash=a326d4078d0bee69
scope.1.id=function:_set_optional_ui_value
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=13
scope.1.semanticHash=b4ae1d5632e59bd1
scope.2.id=function:M.refresh_button
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=24
scope.2.semanticHash=09222fd548926cfb
]]
