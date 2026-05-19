local nodes = {
  canvas = "皮肤商店",
  close_button = "皮肤_关闭",
  page_prev = "皮肤_上一页",
  page_next = "皮肤_下一页",
  slots = {},
  name_labels = {},
  action_buttons = {},
  action_labels = {},
}

for i = 1, 6 do
  local idx = tostring(i)
  nodes.slots[i] = "皮肤_格" .. idx
  nodes.name_labels[i] = "皮肤_格" .. idx .. "_名称"
  nodes.action_buttons[i] = "皮肤_格" .. idx .. "_动作"
  nodes.action_labels[i] = "皮肤_格" .. idx .. "_动作文本"
end

return nodes
