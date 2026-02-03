local market_view = require("src.ui.UIMarket")
local board_view = require("src.ui.BoardView")
local market_ui = require("src.ui.MarketUI")
local ui_aliases = require("src.ui.UIAliases")

local ui_view = {}

local function _query_node(name)
  assert(name ~= nil, "missing ui node name")
  local resolved = ui_aliases.resolve(name)
  local list = UIManager.query_nodes_by_name(resolved)
  assert(list ~= nil and list[1] ~= nil, "missing ui node: " .. tostring(name))
  return list[1]
end

local function _set_label(_, name, text)
  local node = _query_node(name)
  node.text = text or ""
end

local function _set_button(_, name, text)
  local node = _query_node(name)
  node.text = text or ""
end

local function _set_visible(_, name, visible)
  local node = _query_node(name)
  node.visible = visible == true
end

local function _set_touch_enabled(_, name, enabled)
  local node = _query_node(name)
  node.disabled = not enabled
end

function ui_view.build_ui_state()
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
    query_node = _query_node,
    set_label = _set_label,
    set_button = _set_button,
    set_visible = _set_visible,
    set_touch_enabled = _set_touch_enabled,
  }
end

function ui_view.init_ui_assets(layer)
  assert(layer ~= nil, "missing state")
  local refs = require("src.runtime.Refs")
  layer.ui_refs = refs

  local function set_item_slot_image(slot_name, image_key)
    assert(slot_name ~= nil, "missing slot name")
    assert(image_key ~= nil, "missing image key for slot: " .. tostring(slot_name))
    local nodes = UIManager.query_nodes_by_name(slot_name)
    assert(nodes ~= nil, "missing ui nodes for slot: " .. tostring(slot_name))
    for _, node in ipairs(nodes) do
      node.image_texture = image_key
    end
  end

  for _, role in ipairs(all_roles) do
    UIManager.client_role = role
    for i = 1, 5 do
      local num = 3000 + i
      local image_key = refs[tostring(num)]
      assert(image_key ~= nil, "missing item icon: " .. tostring(num))
      set_item_slot_image("道具槽位" .. tostring(i), image_key)
    end
  end
  UIManager.client_role = nil
end

function ui_view.refresh_panel(layer, ui_model)
  local ui = layer.ui
  local panel = assert(ui_model.panel, "missing ui_model.panel")

  ui:set_label("倒计时", panel.turn_label)
  local player_rows = panel.player_rows or {}
  for i = 1, 4 do
    local row = player_rows[i]
    assert(row ~= nil, "missing player row: " .. tostring(i))
    ui:set_label("玩家" .. tostring(i) .. "名字", row.name)
    ui:set_label("玩家" .. tostring(i) .. "现金", row.cash)
    ui:set_label("玩家" .. tostring(i) .. "地块数量", row.land_count)
    ui:set_label("玩家" .. tostring(i) .. "总资产", row.total_assets)
  end

  ui_view.refresh_item_slots(layer, ui_model)

  local auto_label = panel.auto_label
  ui:set_button("行动按钮", "下一回合")
  ui:set_button("托管按钮", auto_label)
  ui:set_button("自动控制按钮", auto_label)
end

function ui_view.refresh_turn_label(layer, label_text)
  local ui = layer.ui
  if not ui or not ui.set_label then
    return
  end
  ui:set_label("倒计时", label_text)
end

function ui_view.refresh_item_slots(layer, ui_model)
  local ui = layer.ui
  assert(ui ~= nil and ui.item_slots ~= nil, "missing ui item slots")

  local slots = ui.item_slots
  local item_ids = {}
  ui.item_slot_item_ids = item_ids

  local items = ui_model.item_slots or {}
  local refs = layer.ui_refs
  local empty_key = refs["空"]

  for i, slot_name in ipairs(slots) do
    local item_id = items[i]
    if item_id then
      local ref_key = refs[tostring(item_id)] or refs[item_id]
      local node = ui.query_node(slot_name)
      if ref_key then
        node.image_texture = ref_key
      else
        node.image_texture = empty_key
      end
      ui:set_touch_enabled(slot_name, true)
      item_ids[i] = item_id
    else
      local node = ui.query_node(slot_name)
      node.image_texture = empty_key
      ui:set_touch_enabled(slot_name, false)
    end
  end
end

function ui_view.refresh_board(layer, ui_model, log_once, build_log_prefix)
  board_view.refresh_board(layer, ui_model, log_once, build_log_prefix)
end

function ui_view.render(layer, ui_model, log_once, build_log_prefix)
  ui_view.refresh_panel(layer, ui_model)
  ui_view.refresh_board(layer, ui_model, log_once, build_log_prefix)
end

function ui_view.on_tile_upgraded(layer, tile_id, level)
  board_view.on_tile_upgraded(layer, tile_id, level)
end

function ui_view.on_tile_owner_changed(layer, tile_id, owner_id)
  board_view.on_tile_owner_changed(layer, tile_id, owner_id)
end

function ui_view.select_market_option(layer, option_id)
  market_view.select_market_option(layer, option_id)
end

function ui_view.open_choice_modal(layer, choice, market)
  assert(choice ~= nil, "missing choice")
  local choice_id = assert(choice.id, "missing choice id")
  if layer.pending_choice_id == choice_id
      and (layer.ui.choice_active or layer.ui.market_active) then
    return
  end
  layer.ui_dirty = true

  if choice.kind == "market_buy" and market_ui.is_panel_ready() then
    if layer.ui.choice_active then
      layer.ui:set_visible(layer.ui.choice.root, false)
      layer.ui.choice_active = false
    end
    local market_view = market or {
      choice_id = choice_id,
      options = choice.options,
      allow_cancel = choice.allow_cancel,
      cancel_label = choice.cancel_label,
      selected_option_id = layer.pending_choice_selected_option_id,
    }
    market_view.refresh_market(layer, market_view)
    return
  end
  if layer.ui.market_active then
    market_view.close_market_panel(layer)
  end

  layer.ui:set_label(layer.ui.choice.title, choice.title)
  layer.ui:set_label(layer.ui.choice.body, choice.body)
  layer.ui:set_visible(layer.ui.choice.root, true)

  local option_nodes = layer.ui.choice.option_buttons
  for idx, name in ipairs(option_nodes) do
    local opt = choice.options[idx]
    if opt then
      layer.ui:set_button(name, opt.label)
      layer.ui:set_visible(name, true)
      layer.ui:set_touch_enabled(name, true)
    else
      layer.ui:set_visible(name, false)
      layer.ui:set_touch_enabled(name, false)
    end
  end

  if not choice.allow_cancel then
    layer.ui:set_visible(layer.ui.choice.cancel, false)
    layer.ui:set_touch_enabled(layer.ui.choice.cancel, false)
  else
    layer.ui:set_button(layer.ui.choice.cancel, choice.cancel_label)
    layer.ui:set_visible(layer.ui.choice.cancel, true)
    layer.ui:set_touch_enabled(layer.ui.choice.cancel, true)
  end

  layer.ui.choice_active = true
  layer.pending_choice_elapsed = 0
  layer.pending_choice_id = choice_id
end

function ui_view.close_choice_modal(layer)
  if layer.ui.choice_active then
    layer.ui:set_visible(layer.ui.choice.root, false)
    layer.ui.choice_active = false
  end
  if layer.ui.market_active then
    market_view.close_market_panel(layer)
  end
  layer.market_choice_option_ids = nil
  layer.pending_choice_selected_option_id = nil
  layer.ui_dirty = true
end

function ui_view.push_popup(layer, payload)
  assert(payload ~= nil, "missing popup payload")
  layer.ui:set_label(layer.ui.popup.title, payload.title)
  layer.ui:set_label(layer.ui.popup.body, payload.body)
  layer.ui:set_button(layer.ui.popup.confirm, payload.button_text)
  layer.ui:set_visible(layer.ui.popup.root, true)
  layer.ui.popup_active = true
  layer.ui.popup_payload = payload
  layer.ui.popup_seq = layer.ui.popup_seq + 1
  layer.ui_dirty = true
  return true
end

function ui_view.close_popup(layer)
  assert(layer.ui.popup_active == true, "popup not active")
  layer.ui:set_visible(layer.ui.popup.root, false)
  layer.ui.popup_active = false
  layer.ui.popup_payload = nil
  layer.ui_dirty = true
end

return ui_view
