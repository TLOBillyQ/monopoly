local Prefab = require("Data.Prefab")

local M = {}

M.INIT_STATUS = "__init__"

M.status_specs = {
  hospital  = { scene_eui_key = "医院状态", text_node_name = "医院状态-剩余回合", remaining_field = "stay_turns" },
  mountain  = { scene_eui_key = "深山状态", text_node_name = "深山状态-剩余回合", remaining_field = "stay_turns" },
  roadblock = { scene_eui_key = "路障状态", text_node_name = "路障状态-剩余回合", remaining_field = "stay_turns" },
  rich      = { scene_eui_key = "财神状态", text_node_name = "财神状态-剩余回合", remaining_field = "deity_remaining" },
  poor      = { scene_eui_key = "穷神状态", text_node_name = "穷神状态-剩余回合", remaining_field = "deity_remaining" },
  angel     = { scene_eui_key = "天使状态", text_node_name = "天使状态-剩余回合", remaining_field = "deity_remaining" },
}

M.status_priority = { "hospital", "mountain", "roadblock", "poor", "rich", "angel" }

function M.get_layout_id(status_key)
  local spec = M.status_specs[status_key]
  if not spec then return nil end
  return Prefab.scene_eui and Prefab.scene_eui[spec.scene_eui_key]
end

return M
