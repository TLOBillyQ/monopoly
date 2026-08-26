local unit_lifecycle = {}

local function _has_game_api(method_name)
  return GameAPI and type(GameAPI[method_name]) == "function"
end

local function _call_create(method_name, ...)
  if not _has_game_api(method_name) then
    return nil, "missing GameAPI." .. method_name
  end
  return GameAPI[method_name](...)
end

local function _call_destroy(method_name, ...)
  if not _has_game_api(method_name) then
    return false
  end
  GameAPI[method_name](...)
  return true
end

function unit_lifecycle.create_unit_group(group_id, pos, rotation)
  return _call_create("create_unit_group", group_id, pos, rotation)
end

function unit_lifecycle.create_unit_with_scale(unit_id, pos, rotation, scale)
  return _call_create("create_unit_with_scale", unit_id, pos, rotation, scale)
end

function unit_lifecycle.destroy_unit_with_children(handle, include_children)
  return _call_destroy("destroy_unit_with_children", handle, include_children == true)
end

function unit_lifecycle.destroy_unit(handle)
  return _call_destroy("destroy_unit", handle)
end

return unit_lifecycle

--[[ mutate4lua-manifest
version=4
projectHash=feb0babdde7e7414
scope.0.id=chunk:src/host/units.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=439f1869600f33cf
scope.1.id=function:_has_game_api
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=d9d4d5cad5fbfa39
scope.2.id=function:_call_create
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=12
scope.2.semanticHash=2a8e457fda55bde9
scope.3.id=function:_call_destroy
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=20
scope.3.semanticHash=cd7249678ae40443
scope.4.id=function:unit_lifecycle.create_unit_group
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=245738c77c63904d
scope.5.id=function:unit_lifecycle.create_unit_with_scale
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=28
scope.5.semanticHash=8781ddaf0442289d
scope.6.id=function:unit_lifecycle.destroy_unit_with_children
scope.6.kind=function
scope.6.startLine=30
scope.6.endLine=32
scope.6.semanticHash=d607a8b8e8823f6f
scope.7.id=function:unit_lifecycle.destroy_unit
scope.7.kind=function
scope.7.startLine=34
scope.7.endLine=36
scope.7.semanticHash=d633215b354ea97d
]]
