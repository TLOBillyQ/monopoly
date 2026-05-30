local Prefab = require("Data.Prefab")
local status3d_nodes = require("src.ui.schema.status3d")

local M = {}

M.INIT_STATUS = "__init__"

M.status_specs = {
  hospital  = { scene_eui_key = "医院状态", text_node_name = status3d_nodes.hospital.text_node_name, remaining_field = "stay_turns" },
  mountain  = { scene_eui_key = "深山状态", text_node_name = status3d_nodes.mountain.text_node_name, remaining_field = "stay_turns" },
  roadblock = { scene_eui_key = "路障状态", text_node_name = status3d_nodes.roadblock.text_node_name, remaining_field = "stay_turns" },
  rich      = { scene_eui_key = "财神状态", text_node_name = status3d_nodes.rich.text_node_name, remaining_field = "deity_remaining" },
  poor      = { scene_eui_key = "穷神状态", text_node_name = status3d_nodes.poor.text_node_name, remaining_field = "deity_remaining" },
  angel     = { scene_eui_key = "天使状态", text_node_name = status3d_nodes.angel.text_node_name, remaining_field = "deity_remaining" },
}

M.status_priority = { "hospital", "mountain", "roadblock", "poor", "rich", "angel" }

function M.get_layout_id(status_key)
  local spec = M.status_specs[status_key]
  if not spec then return nil end
  return Prefab.scene_eui and Prefab.scene_eui[spec.scene_eui_key]
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=404c915c5d7bb755
scope.0.id=chunk:src/ui/render/status3d/specs.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=72d86a18fb288225
scope.1.id=function:M.get_layout_id:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=22
scope.1.semanticHash=d10dc54dc31f5c8e
]]
