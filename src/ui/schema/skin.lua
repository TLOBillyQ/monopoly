local nodes = {
  canvas = "皮肤商店",
  close_button = "皮肤商店-关闭",
  title_label = "皮肤_皮肤商店文本",
  card_images = {},
  card_frames = {},
  card_outlines = {},
  price_icons = {},
  action_buttons = {},
}

for i = 1, 6 do
  local idx = tostring(i)
  nodes.card_images[i] = "皮肤_卡牌" .. idx
  nodes.card_frames[i] = "皮肤_卡牌底框" .. idx
  nodes.card_outlines[i] = "皮肤_卡牌底框描边" .. idx
  nodes.price_icons[i] = "皮肤_卡牌金额图标" .. idx
  nodes.action_buttons[i] = "皮肤_穿上按钮" .. idx
end

return nodes
