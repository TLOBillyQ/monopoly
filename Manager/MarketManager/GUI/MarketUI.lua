local MarketUI = {
  container = "黑市屏",
  confirm_button = "黑市购买按钮",
  cancel_button = "关闭",
  price_label = "售价：100",
  selected_card = "选中卡牌",
  item_buttons = {
    "黑市购买项1",
    "黑市购买项2",
    "黑市购买项3",
    "黑市购买项4",
    "黑市购买项5",
    "黑市购买项6",
    "黑市购买项7",
    "黑市购买项8",
    "黑市购买项9",
    "黑市购买项10",
  },
  item_labels = {
    "道具名称1",
    "道具名称2",
    "道具名称3",
    "道具名称4",
    "道具名称5",
    "道具名称6",
    "道具名称7",
    "道具名称8",
    "道具名称9",
    "道具名称10",
  },
  item_frames = {
    "底框1",
    "底框2",
    "底框3",
    "底框4",
    "底框5",
    "底框6",
    "底框7",
    "底框8",
    "底框9",
    "底框10",
  },
  title = "黑市",
  icon_placeholder = "选中卡牌",
  rarity_ref_keys = { [1] = "lv1", [2] = "lv2", [3] = "lv3" },
  empty_ref_key = "空",
}

function MarketUI.is_ready()
  return type(MarketUI.container) == "string" and MarketUI.container ~= ""
    and type(MarketUI.confirm_button) == "string" and MarketUI.confirm_button ~= ""
end

function MarketUI.is_panel_ready()
  return MarketUI.is_ready()
    and type(MarketUI.item_buttons) == "table" and #MarketUI.item_buttons > 0
    and type(MarketUI.item_labels) == "table" and #MarketUI.item_labels > 0
end

return MarketUI
