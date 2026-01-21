local UIState = {}

local function query_ui_manager_node(name)
  if not name then
    return nil
  end
  local manager = rawget(_G, "UIManager")
  if not manager then
    local ok, mod = pcall(require, "UIManager")
    if ok then
      manager = mod
    end
  end
  if manager and manager.query_nodes_by_name then
    local list = manager.query_nodes_by_name(name)
    if list and list[1] then
      return list[1]
    end
  end
  return nil
end

local function safe_query_node(name)
  local node = query_ui_manager_node(name)
  if node ~= nil then
    return node
  end
  if not (name and LuaAPI and LuaAPI.query_ui_node) then
    return nil
  end
  return LuaAPI.query_ui_node(name)
end

local function safe_set_label(node, text)
  if not (node and Role and Role.set_label_text) then
    return
  end
  Role.set_label_text(node, text or "")
end

local function safe_set_button(node, text)
  if not (node and Role and Role.set_button_text) then
    return
  end
  Role.set_button_text(node, text or "")
end

local function safe_set_visible(node, visible)
  if not (node and Role and Role.set_node_visible) then
    return
  end
  Role.set_node_visible(node, visible == true)
end

local function safe_set_touch_enabled(node, enabled)
  if not (node and Role and Role.set_node_touch_enabled) then
    return
  end
  Role.set_node_touch_enabled(node, enabled == true)
end

function UIState.create()
  return {
    auto_play = false,
    auto_interval = 0.1,
    nodes = {},
    selected_tile = nil,
    choice = {
      root = "modal_choice",
      title = "choice_title",
      body = "choice_body",
      cancel = "choice_cancel",
      option_buttons = {
        "choice_option_1",
        "choice_option_2",
        "choice_option_3",
        "choice_option_4",
      },
    },
    popup = {
      root = "modal_popup",
      title = "popup_title",
      body = "popup_body",
      confirm = "popup_confirm",
    },
  }
end

function UIState.get_node(self, name)
  if not name then
    return nil
  end
  if self.nodes[name] ~= nil then
    return self.nodes[name]
  end
  local node = safe_query_node(name)
  if node ~= nil then
    self.nodes[name] = node
  end
  return node
end

function UIState.set_label(self, name, text)
  safe_set_label(self:get_node(name), text)
end

function UIState.set_button(self, name, text)
  safe_set_button(self:get_node(name), text)
end

function UIState.set_visible(self, name, visible)
  safe_set_visible(self:get_node(name), visible)
end

function UIState.set_touch_enabled(self, name, enabled)
  safe_set_touch_enabled(self:get_node(name), enabled)
end

return UIState
