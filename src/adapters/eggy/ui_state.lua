local UIState = {}

-- Map logical node ids used by code to the current UI resource names.
local DIRECT_NAME_MAP = {
  btn_auto = "自动控制底",
  btn_next = "圆形金",
  modal_popup = "弹窗屏",
  popup_confirm = "关闭",
  panel_player_1 = "玩家1名字",
  panel_player_2 = "玩家2名字",
  panel_player_3 = "玩家3名字",
  panel_player_4 = "玩家4名字",
  panel_player_1_detail = "玩家1总资产",
  panel_player_2_detail = "玩家2总资产",
  panel_player_3_detail = "玩家3总资产",
  panel_player_4_detail = "玩家4总资产",
}

local function resolve_ui_name(name)
  if not name then
    return nil
  end
  local mapped = DIRECT_NAME_MAP[name]
  if mapped then
    return mapped
  end

  local slot_idx = string.match(name, "^item_slot_(%d+)$")
  if slot_idx then
    return "道具槽位" .. tostring(slot_idx)
  end

  return name
end

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
  local resolved = resolve_ui_name(name)
  local candidates = { resolved }
  if resolved ~= name then
    candidates[#candidates + 1] = name
  end
  for i = 1, #candidates do
    local candidate = candidates[i]
    local node = query_ui_manager_node(candidate)
    if node ~= nil then
      return node, candidate
    end
  end
  for i = 1, #candidates do
    local candidate = candidates[i]
    if candidate and LuaAPI and LuaAPI.query_ui_node then
      local node = LuaAPI.query_ui_node(candidate)
      if node ~= nil then
        return node, candidate
      end
    end
  end
  return nil, resolved
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
    item_slots = {
      "item_slot_1",
      "item_slot_2",
      "item_slot_3",
      "item_slot_4",
      "item_slot_5",
    },
    market_active = false,
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
  local node, resolved = safe_query_node(name)
  if node ~= nil then
    self.nodes[name] = node
    if resolved and resolved ~= name then
      self.nodes[resolved] = node
    end
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