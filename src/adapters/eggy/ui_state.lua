local UIState = {}

-- Map logical node ids used by code to the current UI resource names.
local DIRECT_NAME_MAP = {
  btn_auto = "btn_auto",
  btn_next = "btn_next",
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

  return name
end

local function query_ui_manager_node(name)
  if not name then
    return nil
  end
  local list = UIManager.query_nodes_by_name(name)
  if list and list[1] then
    return list[1]
  end

  return nil
end

function UIState.create()
  return {
    auto_play = false,
    auto_interval = 0.1,
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
  local resolved = resolve_ui_name(name)
  local candidates = { resolved }
  if resolved ~= name then
    candidates[#candidates + 1] = name
  end
  local node = nil
  for i = 1, #candidates do
    local candidate = candidates[i]
    node = query_ui_manager_node(candidate)
    if node ~= nil then
      resolved = candidate
      break
    end
  end
  return node
end

function UIState.set_label(self, name, text)
  local node = self:get_node(name)
  if node and node.text ~= nil then
    node.text = text or ""
  end
end

function UIState.set_button(self, name, text)
  local node = self:get_node(name)
  if node and node.text ~= nil then
    node.text = text or ""
  end
end

function UIState.set_visible(self, name, visible)
  local node = self:get_node(name)
  if node and node.visible ~= nil then
    node.visible = visible == true
  end
end

function UIState.set_touch_enabled(self, name, enabled)
  local node = self:get_node(name)
  if node and node.disabled ~= nil then
    node.disabled = not enabled
  end
end

return UIState
