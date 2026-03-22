local scene_ui = {}

function scene_ui.set_scene_ui_visible(layer, role, visible)
  if not (GameAPI and type(GameAPI.set_scene_ui_visible) == "function") then
    return false
  end
  local ok = pcall(GameAPI.set_scene_ui_visible, layer, role, visible == true)
  return ok
end

function scene_ui.destroy_scene_ui(layer)
  if not (GameAPI and type(GameAPI.destroy_scene_ui) == "function") then
    return false
  end
  local ok = pcall(GameAPI.destroy_scene_ui, layer)
  return ok
end

function scene_ui.has_scene_ui_support()
  return GameAPI
    and type(GameAPI.set_scene_ui_visible) == "function"
    and true
    or false
end

return scene_ui
