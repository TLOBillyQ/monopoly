local Prefab = require("Data.Prefab")

local M = {}

M.INIT_STATUS = "__init__"

M.status_specs = {
  hospital  = { scene_eui_key = "医院状态" },
  mountain  = { scene_eui_key = "深山状态" },
  roadblock = { scene_eui_key = "路障状态" },
  rich      = { scene_eui_key = "财神状态" },
  poor      = { scene_eui_key = "穷神状态" },
  angel     = { scene_eui_key = "天使状态" },
}

M.status_priority = { "hospital", "mountain", "roadblock", "poor", "rich", "angel" }

M.text_statuses = { hospital = true, mountain = true, roadblock = true }

function M.get_layout_id(status_key)
  local spec = M.status_specs[status_key]
  if not spec then return nil end
  return Prefab.scene_eui and Prefab.scene_eui[spec.scene_eui_key]
end

return M
