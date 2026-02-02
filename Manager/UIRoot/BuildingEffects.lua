local Prefab = require("Data.Prefab")

local BuildingEffects = {}

function BuildingEffects.spawn_upgrade_building_units(scene, root_quaternion, building_index, level)
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
    GameAPI.destroy_unit_with_children(groups[idx], true)
    groups[idx] = nil
  end
  local pos = buildings[idx].get_position()
  local ref_key = string.format("lv%d", lv)
  local unit = GameAPI.create_unit_group(Prefab.group[ref_key], pos + offsets[lv], root_quaternion)
  groups[idx] = unit
end

return BuildingEffects
