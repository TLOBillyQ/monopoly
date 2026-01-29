local PanelView = require("Manager.Adapter.Core.UIPanel")

local EggyLayerUI = {}

local alias_map = {
  choice_option_1 = "choice_option1",
  choice_option_2 = "choice_option2",
  choice_option_3 = "choice_option3",
  choice_option_4 = "choice_option4",
}

for i = 1, 10 do
  alias_map["market_item_button_" .. tostring(i)] = "market_item_button" .. tostring(i)
end

local missing_tips = {}

local function resolve_node_name(name)
  return alias_map[name] or name
end

local function show_missing_tip(name)
  if missing_tips[name] then
    return
  end
  missing_tips[name] = true
  GlobalAPI.show_tips("UI 节点未适配：" .. tostring(name))
end

local function query_node(name)
  if not name then
    return nil
  end
  local resolved = resolve_node_name(name)
  local list = UIManager.query_nodes_by_name(resolved)
  local node = list and list[1] or nil
  if not node then
    show_missing_tip(name)
  end
  return node
end

local function set_label(_, name, text)
  local node = query_node(name)
  if node and node.text ~= nil then
    node.text = text or ""
  end
end

local function set_button(_, name, text)
  local node = query_node(name)
  if node and node.text ~= nil then
    node.text = text or ""
  end
end

local function set_visible(_, name, visible)
  local node = query_node(name)
  if node and node.visible ~= nil then
    node.visible = visible == true
  end
end

local function set_touch_enabled(_, name, enabled)
  local node = query_node(name)
  if node and node.disabled ~= nil then
    node.disabled = not enabled
  end
end

function EggyLayerUI.build_ui_state()
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
    choice = {
      root = "modal_choice",
      title = "choice_title",
      body = "choice_body",
      cancel = "choice_cancel",
      option_buttons = {
        "choice_option1",
        "choice_option2",
        "choice_option3",
        "choice_option4",
      },
    },
    popup = {
      root = "modal_popup",
      title = "popup_title",
      body = "popup_body",
      confirm = "popup_confirm",
    },
    query_node = query_node,
    set_label = set_label,
    set_button = set_button,
    set_visible = set_visible,
    set_touch_enabled = set_touch_enabled,
  }
end

function EggyLayerUI.refresh_panel(layer, view)
  local ui = layer.ui
  local turn_label = PanelView.build_turn_label(view.state.turn.turn_count)

  ui:set_label("panel_title", "蛋仔大富翁")
  ui:set_label("panel_turn", turn_label)
  local player_rows = PanelView.build_player_statuses(view, layer.game, 4)
  for i = 1, 4 do
    local row = player_rows[i]
    ui:set_label("panel_player_" .. tostring(i) .. "_name", row and row.name or "")
    ui:set_label("panel_player_" .. tostring(i) .. "_cash", row and row.cash or "")
    ui:set_label("panel_player_" .. tostring(i) .. "_land_count", row and row.land_count or "")
    ui:set_label("panel_player_" .. tostring(i) .. "_detail", row and row.total_assets or "")
  end

  EggyLayerUI.refresh_item_slots(layer, view)

  ui:set_button("btn_next", "下一回合")
  ui:set_button("btn_auto", PanelView.build_auto_label(ui.auto_play))
end

function EggyLayerUI.refresh_item_slots(layer, view)
  local ui = layer.ui
  if not (ui and ui.item_slots) then
    return
  end

  local slots = ui.item_slots
  local item_ids = {}
  ui.item_slot_item_ids = item_ids

  local players = view and view.state and view.state.players or nil
  local turn = view and view.state and view.state.turn or nil
  local current = players and turn and players[turn.current_player_index] or nil
  local items = current and current.inventory and current.inventory.items or {}
  local refs = G and G.refs or nil
  local empty_key = refs and refs["空"] or nil

  for i, slot_name in ipairs(slots) do
    local item = items[i]
    if item and item.id then
      if refs then
        local ref_key = refs[tostring(item.id)] or refs[item.id]
        local node = ui.query_node(slot_name)
        if node and node.image_texture ~= nil then
          if ref_key then
            node.image_texture = ref_key
          elseif empty_key then
            node.image_texture = empty_key
          end
        end
      end
      ui:set_touch_enabled(slot_name, true)
      item_ids[i] = item.id
    else
      local node = ui.query_node(slot_name)
      if node and node.image_texture ~= nil and empty_key then
        node.image_texture = empty_key
      end
      ui:set_touch_enabled(slot_name, false)
    end
  end
end

return EggyLayerUI
