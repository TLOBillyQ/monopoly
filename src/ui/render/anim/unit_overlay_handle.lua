local host_types = require("src.foundation.host_types")

local handle_ops = {}
local robot_scale = host_types.vec3(0.06, 0.94, 0.06)
local robot_rotation = host_types.quat(0.0, 0.0, 0.0)

local function _access_field(obj, key)
  return obj[key]
end

local function _call_handle_method(handle, method_name, ...)
  if handle == nil then return false end
  local ok, method = pcall(_access_field, handle, method_name)
  if not ok or type(method) ~= "function" then return false end
  local called = pcall(method, ...)
  return called == true
end

function handle_ops.spawn(hr, robot_id, pos)
  if robot_id == nil then
    return nil
  end
  if type(hr.acquire_unit) == "function" then
    return hr.acquire_unit(robot_id, pos, robot_rotation, robot_scale)
  end
  if type(hr.create_unit_with_scale) ~= "function" then
    return nil
  end
  return hr.create_unit_with_scale(robot_id, pos, robot_rotation, robot_scale)
end

function handle_ops.destroy(hr, robot_id, handle)
  if handle == nil then
    return
  end
  if type(hr.release_unit) == "function" then
    hr.release_unit(robot_id, handle)
    return
  end
  if type(hr.destroy_unit) == "function" then
    hr.destroy_unit(handle)
    return
  end
  if type(hr.destroy_unit_with_children) == "function" then
    hr.destroy_unit_with_children(handle, true)
    return
  end
end

function handle_ops.move(hr, robot_id, handle, pos)
  if _call_handle_method(handle, "set_position_smooth", pos) then
    return handle
  end
  if _call_handle_method(handle, "set_position", pos) then
    return handle
  end
  handle_ops.destroy(hr, robot_id, handle)
  return handle_ops.spawn(hr, robot_id, pos)
end

return handle_ops

--[[ mutate4lua-manifest
version=2
projectHash=8463c3e8b7cc947b
scope.0.id=chunk:src/ui/render/anim/unit_overlay_handle.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=62
scope.0.semanticHash=f4090047eea919a0
scope.1.id=function:_access_field:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=e28a6b558e3f7cfb
scope.2.id=function:_call_handle_method:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=17
scope.2.semanticHash=f4fb084bfabb06c1
scope.3.id=function:handle_ops.spawn:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=30
scope.3.semanticHash=7323ab46d8fb1030
scope.4.id=function:handle_ops.destroy:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=48
scope.4.semanticHash=49d1b58b4cd4a9bd
scope.5.id=function:handle_ops.move:50
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=59
scope.5.semanticHash=98b0c08e6a0b20d3
]]
