local BuildingEffects = {}

function BuildingEffects.spawn_upgrade_building_units(root_quaternion, building_index, level)
  local offsets = {
    [1] = math.Vector3(0, 1.5, 0),
    [2] = math.Vector3(0, 1.5, 0),
    [3] = math.Vector3(1, 1.5, 0),
  }
  local buildings = G.buildings
  local refs = G.refs
  local idx = building_index or 1
  local lv = level or 1
  local groups = G.building_unit_groups
  if groups and groups[idx] then
    if GameAPI and GameAPI.destroy_unit_with_children then
      GameAPI.destroy_unit_with_children(groups[idx], true)
    elseif GameAPI and GameAPI.destroy_unit then
      GameAPI.destroy_unit(groups[idx])
    end
    groups[idx] = nil
  end
  local pos = buildings[idx].get_position()
  local ref_key = "lv" .. tostring(lv)
  local unit = GameAPI.create_unit_group(refs[ref_key], pos + offsets[lv], root_quaternion)
  if not groups then
    groups = {}
    G.building_unit_groups = groups
  end
  groups[idx] = unit
end

return BuildingEffects
