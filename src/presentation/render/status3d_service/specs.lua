local M = {}

M.INIT_STATUS = "__init__"
M.status_node_specs = {
  hospital = { bg = "医院状态-底图", text = "医院状态-文本" },
  mountain = { bg = "深山状态-底图", text = "深山状态-文本" },
  roadblock = { bg = "路障状态-底图", text = "路障状态-文本" },
  rich = { bg = "财神状态-底图", text = "财神状态-文本" },
  poor = { bg = "穷神状态-底图", text = "穷神状态-文本" },
  angel = { bg = "天使状态-底图", text = "天使状态-文本" },
}
M.status_priority = { "hospital", "mountain", "roadblock", "poor", "rich", "angel" }

local lookup = {}
for status_key, spec in pairs(M.status_node_specs) do
  lookup[spec.bg] = { status_key = status_key, node_type = "bg" }
  lookup[spec.text] = { status_key = status_key, node_type = "text" }
end
M.status_node_name_lookup = lookup

return M
