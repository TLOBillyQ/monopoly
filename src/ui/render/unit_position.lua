local unit_position = {}

local function _access_get_position(unit)
  return unit.get_position
end

local function _resolve_get_position(unit)
  if unit == nil then
    return nil
  end
  local ok, getter = pcall(_access_get_position, unit)
  if not ok or type(getter) ~= "function" then
    return nil
  end
  return getter
end

function unit_position.read_unit_position(unit)
  local getter = _resolve_get_position(unit)
  if getter == nil then
    return nil
  end
  local ok, pos = pcall(getter)
  if not ok then
    return nil
  end
  return pos
end

local function _read_indexed_position(units, index)
  if units == nil or index == nil then
    return nil
  end
  return unit_position.read_unit_position(units[index])
end

function unit_position.read_scene_tile_position(scene, tile_index)
  return _read_indexed_position(scene and scene.tiles or nil, tile_index)
end

function unit_position.read_scene_building_position(scene, tile_index)
  return _read_indexed_position(scene and scene.buildings or nil, tile_index)
end

return unit_position

--[[ mutate4lua-manifest
version=2
projectHash=6035b7b5b69f7195
scope.0.id=chunk:src/ui/render/unit_position.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=5736f6cd11c0059c
scope.1.id=function:_access_get_position:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=12efd0ed165cd4af
scope.2.id=function:_resolve_get_position:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=16
scope.2.semanticHash=ddb79b0345edbc16
scope.3.id=function:unit_position.read_unit_position:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=28
scope.3.semanticHash=dbf17fb8f29d32c1
scope.4.id=function:_read_indexed_position:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=35
scope.4.semanticHash=215fdc9bb4fa6c66
scope.5.id=function:unit_position.read_scene_tile_position:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=39
scope.5.semanticHash=7be5d1d6d608fd55
scope.6.id=function:unit_position.read_scene_building_position:41
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=43
scope.6.semanticHash=8b604844f0ec7f49
]]
