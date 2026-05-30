local prefab = require("Data.Prefab")
local host_runtime_resolver = require("src.ui.render.host_runtime_resolver")

local building_effects = {}

local _resolve_host_runtime = host_runtime_resolver.from_state

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

--[[ mutate4lua-manifest
version=2
projectHash=fa469fb944e88cea
scope.0.id=chunk:src/ui/render/building_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=80
scope.0.semanticHash=7d2f3cff1b3c8147
scope.1.id=function:building_effects.clear_building_units:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=22
scope.1.semanticHash=58f98b2791a86005
scope.2.id=function:_offset_for_level:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=42
scope.2.semanticHash=d5fda505523c637e
scope.3.id=function:building_effects.spawn_upgrade_building_units:44
scope.3.kind=function
scope.3.startLine=44
scope.3.endLine=77
scope.3.semanticHash=028eff27dd876c85
]]
