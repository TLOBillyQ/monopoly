local nodes = {
  canvas = "黑市屏",
  confirm = "黑市_购买按钮",
  cancel = "黑市_取消按钮",
  close = "黑市_关闭",
  price_label = "黑市_售价",
  selected_card = "黑市_选中卡牌",
  item_buttons = {},
  item_labels = {},
  item_frames = {},
}

for i = 1, 10 do
  local idx = tostring(i)
  nodes.item_buttons[i] = "黑市_购买项" .. idx
  nodes.item_labels[i] = "黑市_道具名称" .. idx
  nodes.item_frames[i] = "黑市_底框" .. idx
end

return nodes
