local nodes = {
  canvas = "黑市屏",
  confirm = "黑市_购买按钮",
  cancel = "黑市_取消按钮",
  close = "黑市_关闭",
  page_prev = "黑市-上一页箭头",
  page_next = "黑市-下一页箭头",
  tab_item = "黑市-道具商店按钮",
  price_label = "黑市_售价",
  selected_card = "黑市_选中卡牌",
  item_buttons = {},
  item_labels = {},
  item_frames = {},
  item_selection_frames = {},
}

for i = 1, 10 do
  local idx = tostring(i)
  nodes.item_buttons[i] = "黑市_购买项" .. idx
  nodes.item_labels[i] = "黑市_道具名称" .. idx
  nodes.item_frames[i] = "黑市_底框" .. idx
  nodes.item_selection_frames[i] = "黑市-选中边框" .. idx
end

return nodes

--[[ mutate4lua-manifest
version=2
projectHash=eb51c75e444b85a3
scope.0.id=chunk:src/ui/schema/market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=5138fa437b8b2a5b
]]
