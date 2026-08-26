-- 相机宿主锁操作:props 恢复、直接锁/复位与滤波重锁。
-- 原 ui_sync/camera.lua 的宿主锁段;camera.lua 保留编排与公共面。
local runtime_state = require("src.ui.state.runtime")
local camera_follow = require("src.config.gameplay.camera_follow")
local relock_filter = require("src.ui.ports.ui_sync.camera_relock_filter")

local M = {}

local CAMERA_PROP_DIST = 7
local CAMERA_PROP_OBSERVER_HEIGHT = 11
local CAMERA_PROP_PITCH = 15
local CAMERA_PROP_YAW = 16

local _camera_props = {
  { CAMERA_PROP_DIST, nil },
  { CAMERA_PROP_OBSERVER_HEIGHT, nil },
  { CAMERA_PROP_PITCH, nil },
  { CAMERA_PROP_YAW, nil },
}

local function _restore_camera_props(state, local_role)
  _camera_props[1][2] = camera_follow.dist
  _camera_props[2][2] = camera_follow.observer_height
  _camera_props[3][2] = camera_follow.pitch
  _camera_props[4][2] = camera_follow.yaw
  if type(local_role.set_camera_property) ~= "function" then
    runtime_state.log_once(state, "warn", "camera_sync:set_camera_property_unavailable", "camera_sync", "set_camera_property not available on role")
    return
  end
  for _, entry in ipairs(_camera_props) do
    local prop, value = entry[1], entry[2]
    local ok, err = pcall(local_role.set_camera_property, prop, value)
    if not ok then
      runtime_state.log_once(state, "warn", "camera_sync:set_camera_property_" .. tostring(prop), "camera_sync", "set_camera_property(" .. tostring(prop) .. ") failed:", tostring(err))
    end
  end
end

function M.lock_to_position(state, local_role, target_pos)
  if target_pos == nil then
    return false
  end
  if type(local_role.set_camera_lock_position) ~= "function" then
    return false
  end
  local ok, err = pcall(local_role.set_camera_lock_position, target_pos)
  if not ok then
    runtime_state.log_once(state, "warn", "camera_sync:set_camera_lock_position_failed", "camera_sync", "set_camera_lock_position failed:", tostring(err))
  else
    _restore_camera_props(state, local_role)
    relock_filter.record_baseline(local_role, target_pos)
  end
  return ok == true
end

function M.reset_to_self(state, local_role)
  if type(local_role.reset_camera) ~= "function" then
    return false
  end
  local ok, err = pcall(local_role.reset_camera, true, true, true, true)
  if not ok then
    runtime_state.log_once(state, "warn", "camera_sync:reset_camera_failed", "camera_sync", "reset_camera failed:", tostring(err))
  else
    relock_filter.clear_baseline(local_role)
  end
  return ok == true
end

-- sync 路径专用:滤波后重锁。去重命中说明镜头已钉在目标上,也算同步成功。
function M.sync_lock(state, role, target_pos)
  if target_pos == nil then
    return false
  end
  local filtered = relock_filter.filter_value(role, target_pos)
  if filtered == nil then
    return true
  end
  return M.lock_to_position(state, role, filtered)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=fb3597225930c30e
scope.0.id=chunk:src/ui/ports/ui_sync/camera_lock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=82
scope.0.semanticHash=5b5b80e8927c0298
scope.1.id=function:_restore_camera_props
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=37
scope.1.semanticHash=dfa1a3cf3110e9cf
scope.2.id=function:M.lock_to_position
scope.2.kind=function
scope.2.startLine=39
scope.2.endLine=54
scope.2.semanticHash=3906a7b0d9015e01
scope.3.id=function:M.reset_to_self
scope.3.kind=function
scope.3.startLine=56
scope.3.endLine=67
scope.3.semanticHash=cc1d05396fb7cfed
scope.4.id=function:M.sync_lock
scope.4.kind=function
scope.4.startLine=70
scope.4.endLine=79
scope.4.semanticHash=fc4097edae026c44
]]
