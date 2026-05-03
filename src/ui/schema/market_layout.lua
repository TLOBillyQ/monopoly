local market_layout = {
  container = "黑市屏",
  confirm_button = "黑市_购买按钮",
  cancel_button = "黑市_关闭",
  cancel_button_alt = "黑市_取消按钮",
  page_prev = "黑市-上一页箭头",
  page_next = "黑市-下一页箭头",
  page_prev_label = "黑市-上一页按钮",
  page_next_label = "黑市-下一页按钮",
  page_prev_text = "上一页",
  page_next_text = "下一页",
  tab_item = "黑市-道具商店按钮",
  tab_skin = "黑市-皮肤商店按钮",
  price_label = "黑市_售价",
  selected_card = "黑市_选中卡牌",
  item_buttons = {},
  item_labels = {},
  item_frames = {},
  item_selection_frames = {},
  title = "黑市",
  icon_placeholder = "黑市_选中卡牌",
  rarity_ref_keys = { [1] = "lv1", [2] = "lv2", [3] = "lv3" },
  empty_ref_key = "Empty",
}

market_layout.cancel_buttons = {
  market_layout.cancel_button,
  market_layout.cancel_button_alt,
}

for i = 1, 10 do
  local idx = tostring(i)
  market_layout.item_buttons[i] = "黑市_购买项" .. idx
  market_layout.item_labels[i] = "黑市_道具名称" .. idx
  market_layout.item_frames[i] = "黑市_底框" .. idx
  market_layout.item_selection_frames[i] = "黑市-选中边框" .. idx
end

function market_layout.is_ready()
  return type(market_layout.container) == "string" and market_layout.container ~= ""
    and type(market_layout.confirm_button) == "string" and market_layout.confirm_button ~= ""
end

function market_layout.is_panel_ready()
  return market_layout.is_ready()
    and type(market_layout.item_buttons) == "table" and #market_layout.item_buttons > 0
    and type(market_layout.item_labels) == "table" and #market_layout.item_labels > 0
end

return market_layout
