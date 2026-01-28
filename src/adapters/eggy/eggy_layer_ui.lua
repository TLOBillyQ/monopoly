local logger = require("src.util.logger")
local PanelView = require("src.adapters.core.ui_panel")
local LogView = require("src.adapters.core.ui_log")

local EggyLayerUI = {}

local function query_node(name)
  if not name then
    return nil
  end
  local list = UIManager.query_nodes_by_name(name)
  return list and list[1] or nil
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
  local current_view = PanelView.build_current_player_view(view)

  ui:set_label("panel_title", "蛋仔大富翁")
  ui:set_label("panel_turn", turn_label)
  ui:set_label("panel_current_title", "当前玩家")

  ui:set_label("panel_current_name", current_view and current_view.name_text or "")
  ui:set_label("panel_current_role", current_view and current_view.role_text or "")

  ui:set_label("panel_current_phase", current_view and current_view.phase_text or "")
  ui:set_label("panel_current_dice", current_view and current_view.dice_text or "")

  ui:set_label("panel_players_title", "玩家状态")
  local player_rows = PanelView.build_player_statuses(view, layer.game, 4)
  for i = 1, 4 do
    local row = player_rows[i]
    ui:set_label("panel_player_" .. tostring(i), row and row.name or "")
    ui:set_label("panel_player_" .. tostring(i) .. "_cash", row and row.cash or "")
    ui:set_label("panel_player_" .. tostring(i) .. "_land_count", row and row.land_count or "")
    ui:set_label("panel_player_" .. tostring(i) .. "_detail", row and row.total_assets or "")
  end

  EggyLayerUI.refresh_item_slots(layer, view)

  ui:set_button("btn_next", "下一回合")
  ui:set_button("btn_auto", PanelView.build_auto_label(ui.auto_play))
  ui:set_button("btn_restart", "重新开始")

  local entries = logger.entries or {}
  local log_entries = LogView.build_log_entries(entries, 8)
  local log_lines = {}
  for _, entry in ipairs(log_entries) do
    log_lines[#log_lines + 1] = entry.text
  end
  ui:set_label("panel_log_title", "事件记录")
  ui:set_label("panel_log_body", table.concat(log_lines, "\n"))
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
