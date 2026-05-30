local scene_ui = {}

function scene_ui.set_scene_ui_visible(layer, role, visible)
  if not (GameAPI and type(GameAPI.set_scene_ui_visible) == "function") then
    return false
  end
  return pcall(GameAPI.set_scene_ui_visible, layer, role, visible == true)
end

function scene_ui.destroy_scene_ui(layer)
  if not (GameAPI and type(GameAPI.destroy_scene_ui) == "function") then
    return false
  end
  return pcall(GameAPI.destroy_scene_ui, layer)
end

function scene_ui.has_scene_ui_support()
  return GameAPI
    and type(GameAPI.set_scene_ui_visible) == "function"
    and true
    or false
end

function scene_ui.get_eui_node_at_scene_ui(layer, node_id)
  if not (GameAPI and type(GameAPI.get_eui_node_at_scene_ui) == "function") then
    return nil
  end
  if layer == nil or node_id == nil then
    return nil
  end
  local ok, result = pcall(GameAPI.get_eui_node_at_scene_ui, layer, node_id)
  if not ok then
    return nil
  end
  return result
end

return scene_ui

--[[ mutate4lua-manifest
version=2
projectHash=428e5e310d083f5f
scope.0.id=chunk:src/host/scene_ui.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=7fbce4e514c75487
scope.1.id=function:scene_ui.set_scene_ui_visible:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=1df55a9c7b935488
scope.2.id=function:scene_ui.destroy_scene_ui:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=92a8ff81875b63bb
scope.3.id=function:scene_ui.has_scene_ui_support:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=22
scope.3.semanticHash=67a06ba1a56c4730
scope.4.id=function:scene_ui.get_eui_node_at_scene_ui:24
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=36
scope.4.semanticHash=7b7a3db17e6815bd
]]
