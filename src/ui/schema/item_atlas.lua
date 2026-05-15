local nodes = {
  canvas = "图鉴弹窗",
  close_button = "图鉴_关闭",
  page_prev = "图鉴_上一页",
  page_next = "图鉴_下一页",
  detail_image = "图鉴_大图",
  detail_name = "图鉴_大图名称",
  detail_description = "图鉴_大图描述",
  slots = {},
  name_labels = {},
  image_buttons = {},
}

for i = 1, 8 do
  local idx = tostring(i)
  nodes.slots[i] = "图鉴_格" .. idx
  nodes.name_labels[i] = "图鉴_格" .. idx .. "_名称"
  nodes.image_buttons[i] = "图鉴_格" .. idx .. "_图片"
end

return nodes
