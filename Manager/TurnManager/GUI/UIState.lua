local PanelView = require("Manager.TurnManager.GUI.UIPanel")
local UIAliases = require("Manager.ChoiceManager.GUI.UIAliases")

local EggyLayerUI = {}

local function query_node(name)
  assert(name ~= nil, "missing ui node name")
  local resolved = UIAliases.resolve(name)
  local list = UIManager.query_nodes_by_name(resolved)
  assert(list ~= nil and list[1] ~= nil, "missing ui node: " .. tostring(name))
  return list[1]
end

local function set_label(_, name, text)
  local node = query_node(name)
  node.text = text or ""
end

local function set_button(_, name, text)
  local node = query_node(name)
  node.text = text or ""
end

local function set_visible(_, name, visible)
  local node = query_node(name)
  node.visible = visible == true
end

local function set_touch_enabled(_, name, enabled)
  local node = query_node(name)
  node.disabled = not enabled
end

function EggyLayerUI.build_ui_state()
  return {
    auto_play = false,
    auto_interval = 0.1,
    item_slots = {
      "道具槽位1",
      "道具槽位2",
      "道具槽位3",
      "道具槽位4",
      "道具槽位5",
    },
    market_active = false,
    choice = {
      root = "黑市屏",
      cancel = "取消按钮",
      option_buttons = {
        "道具名称1",
        "道具名称2",
        "道具名称3",
        "道具名称4",
      },
    },
    popup = {
      root = "弹窗屏",
      confirm = "弹窗确认",
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

  ui:set_label("倒计时", turn_label)
  local player_rows = PanelView.build_player_statuses(view, layer.game, 4)
  for i = 1, 4 do
    local row = player_rows[i]
    assert(row ~= nil, "missing player row: " .. tostring(i))
    ui:set_label("玩家" .. tostring(i) .. "名字", row.name)
    ui:set_label("玩家" .. tostring(i) .. "现金", row.cash)
    ui:set_label("玩家" .. tostring(i) .. "地块数量", row.land_count)
    ui:set_label("玩家" .. tostring(i) .. "总资产", row.total_assets)
  end

  EggyLayerUI.refresh_item_slots(layer, view)

  local auto_label = PanelView.build_auto_label(ui.auto_play)
  ui:set_button("行动按钮", "下一回合")
  ui:set_button("托管按钮", auto_label)
  ui:set_button("自动控制按钮", auto_label)
end

function EggyLayerUI.refresh_item_slots(layer, view)
  local ui = layer.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")

  local slots = ui.item_slots
  local item_ids = {}
  ui.item_slot_item_ids = item_ids

  local players = view.state.players
  local turn = view.state.turn
  local current = players[turn.current_player_index]
  local items = current.inventory.items
  local refs = layer.ui_refs
  local empty_key = refs["空"]

  for i, slot_name in ipairs(slots) do
    local item = items[i]
    if item and item.id then
      local ref_key = refs[tostring(item.id)] or refs[item.id]
      local node = ui.query_node(slot_name)
      if ref_key then
        node.image_texture = ref_key
      else
        node.image_texture = empty_key
      end
      ui:set_touch_enabled(slot_name, true)
      item_ids[i] = item.id
    else
      local node = ui.query_node(slot_name)
      node.image_texture = empty_key
      ui:set_touch_enabled(slot_name, false)
    end
  end
end

return EggyLayerUI
