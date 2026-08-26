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

local function _has_set_visible()
  return GameAPI and type(GameAPI.set_scene_ui_visible) == "function"
end

function scene_ui.has_scene_ui_support()
  return _has_set_visible() and true or false
end

local function _has_eui_lookup()
  return GameAPI ~= nil and type(GameAPI.get_eui_node_at_scene_ui) == "function"
end

local function _complete_args(layer, node_id)
  return layer ~= nil and node_id ~= nil
end

function scene_ui.get_eui_node_at_scene_ui(layer, node_id)
  if not _has_eui_lookup() then
    return nil
  end
  if not _complete_args(layer, node_id) then
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
version=4
projectHash=ce34b39eb08ab9d1
scope.0.id=chunk:src/host/scene_ui.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=48
scope.0.semanticHash=34e1ee20cfc2b589
scope.1.id=function:scene_ui.set_scene_ui_visible
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=c79e55f1770fc61f
scope.2.id=function:scene_ui.destroy_scene_ui
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=e0056515d886e6ed
scope.3.id=function:_has_set_visible
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=19
scope.3.semanticHash=a8dc6f51993f12dd
scope.4.id=function:scene_ui.has_scene_ui_support
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=23
scope.4.semanticHash=0134b556c2633ca9
scope.5.id=function:_has_eui_lookup
scope.5.kind=function
scope.5.startLine=25
scope.5.endLine=27
scope.5.semanticHash=1f5ae984b543d519
scope.6.id=function:_complete_args
scope.6.kind=function
scope.6.startLine=29
scope.6.endLine=31
scope.6.semanticHash=a17812a9544dad33
scope.7.id=function:scene_ui.get_eui_node_at_scene_ui
scope.7.kind=function
scope.7.startLine=33
scope.7.endLine=45
scope.7.semanticHash=4fec78c291141867
]]
