local prefab = require("Data.Prefab")
local host_runtime = require("src.presentation.api.HostRuntimePort")

local building_effects = {}

function building_effects.spawn_upgrade_building_units(scene, root_quaternion, building_index, level)
  assert(scene ~= nil, "missing scene")
  assert(building_index ~= nil, "missing building_index")
  assert(level ~= nil, "missing building level")
  local offsets = {
    [1] = math.Vector3(0.0, 1.5, 0.0),
    [2] = math.Vector3(0.0, 1.5, 0.0),
    [3] = math.Vector3(1.0, 1.5, 0.0),
  }
  local buildings = assert(scene.buildings, "missing scene.buildings")
  local idx = building_index
  local lv = level
  local groups = assert(scene.building_unit_groups, "missing scene.building_unit_groups")
  if groups[idx] then
    host_runtime.destroy_unit_with_children(groups[idx], true)
    groups[idx] = nil
  end
  local pos = buildings[idx].get_position()
  local ref_keys = {
    [1] = "一级建筑",
    [2] = "二级建筑",
    [3] = "三级建筑",
  }
  local ref_key = ref_keys[lv]
  local unit = host_runtime.create_unit_group(prefab.group[ref_key], pos + offsets[lv], root_quaternion)
  groups[idx] = unit
  scene.building_txt[idx].set_billboard_text(ref_key)
end

return building_effects
