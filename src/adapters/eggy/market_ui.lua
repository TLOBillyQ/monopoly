local MarketUI = {
  container = "market_panel",
  confirm_button = "market_confirm_button",
  cancel_button = "market_cancel_button",
  price_label = "market_price_label",
  selected_card = "market_selected_card",
  item_buttons = {
    "market_item_button_1",
    "market_item_button_2",
    "market_item_button_3",
    "market_item_button_4",
    "market_item_button_5",
    "market_item_button_6",
    "market_item_button_7",
    "market_item_button_8",
    "market_item_button_9",
    "market_item_button_10",
  },
  item_labels = {
    "market_item_label_1",
    "market_item_label_2",
    "market_item_label_3",
    "market_item_label_4",
    "market_item_label_5",
    "market_item_label_6",
    "market_item_label_7",
    "market_item_label_8",
    "market_item_label_9",
    "market_item_label_10",
  },
  item_frames = {
    "market_item_frame_1",
    "market_item_frame_2",
    "market_item_frame_3",
    "market_item_frame_4",
    "market_item_frame_5",
    "market_item_frame_6",
    "market_item_frame_7",
    "market_item_frame_8",
    "market_item_frame_9",
    "market_item_frame_10",
  },
  item_event_prefix = "market_item_button_",
  choose_event = nil,
  confirm_event = "market_confirm_button",
  cancel_event = "market_cancel_button",
  title = "黑市",
  icon_placeholder = "market_icon_placeholder",
  rarity_ref_keys = { [1] = "lv1", [2] = "lv2", [3] = "lv3" },
  empty_ref_key = "空",
}

function MarketUI.is_ready()
  return type(MarketUI.container) == "string" and MarketUI.container ~= ""
    and type(MarketUI.confirm_event) == "string" and MarketUI.confirm_event ~= ""
    and type(MarketUI.confirm_button) == "string" and MarketUI.confirm_button ~= ""
end

function MarketUI.is_panel_ready()
  return MarketUI.is_ready()
    and type(MarketUI.item_buttons) == "table" and #MarketUI.item_buttons > 0
    and type(MarketUI.item_labels) == "table" and #MarketUI.item_labels > 0
end

return MarketUI
