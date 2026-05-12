local prefab = require("Data.Prefab")
local host_runtime_bridge = require("src.ui.host_bridge")

local building_effects = {}

local function _resolve_host_runtime(scene, deps)
  local resolved_deps = deps or scene and scene.presentation_runtime or nil
  if resolved_deps and resolved_deps.host_runtime then
    return resolved_deps.host_runtime
  end
  return host_runtime_bridge
end

function building_effects.clear_building_units(scene, building_index, deps)
  assert(scene ~= nil, "missing scene")
  assert(building_index ~= nil, "missing building_index")
  local host_runtime = _resolve_host_runtime(scene, deps)
  local groups = scene.building_unit_groups
  if type(groups) == "table" and groups[building_index] then
    host_runtime.destroy_unit_with_children(groups[building_index], true)
    groups[building_index] = nil
  end
  local txt = scene.building_txt and scene.building_txt[building_index] or nil
  if txt and txt.set_billboard_text then
    txt.set_billboard_text("  ")
  end
  return true
end

local _offset_coords = {
  [1] = { x = 0.0, y = 1.5, z = 0.0 },
  [2] = { x = 0.0, y = 1.5, z = 0.0 },
  [3] = { x = 1.0, y = 1.5, z = 0.0 },
}

local _ref_keys = {
  [1] = "一级建筑",
  [2] = "二级建筑",
  [3] = "三级建筑",
}

local function _offset_for_level(level)
  local coords = _offset_coords[level]
  if coords == nil then
    return nil
  end
  return math.Vector3(coords.x, coords.y, coords.z)
end

function building_effects.spawn_upgrade_building_units(scene, root_quaternion, building_index, level, deps)
  assert(scene ~= nil, "missing scene")
  assert(building_index ~= nil, "missing building_index")
  assert(level ~= nil, "missing building level")
  local host_runtime = _resolve_host_runtime(scene, deps)
  local buildings = assert(scene.buildings, "missing scene.buildings")
  local idx = building_index
  local lv = level
  local groups = assert(scene.building_unit_groups, "missing scene.building_unit_groups")
  building_effects.clear_building_units(scene, idx, deps)
  if buildings[idx] == nil then
    return false
  end
  local pos = buildings[idx].get_position()
  local ref_key = _ref_keys[lv]
  local group_id = prefab.group[ref_key]
  if group_id == nil then
    return false
  end
  local offset = _offset_for_level(lv)
  if offset == nil then
    return false
  end
  local unit = host_runtime.create_unit_group(group_id, pos + offset, root_quaternion)
  if unit == nil then
    return false
  end
  groups[idx] = unit
  local txt = scene.building_txt and scene.building_txt[idx] or nil
  if txt and txt.set_billboard_text then
    txt.set_billboard_text(ref_key)
  end
  return true
end

return building_effects
