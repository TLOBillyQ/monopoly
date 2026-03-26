local runtime_ports = require("src.core.ports.runtime_ports")
local logger = require("src.core.utils.logger")

local camera_sync = {}

local CAMERA_BIND_MODE_FIXED = 1

local function _resolve_target_unit(player_id)
  local role = runtime_ports.resolve_role(player_id)
  if not (role and type(role.get_ctrl_unit) == "function") then
    return nil
  end
  local ok, unit = pcall(role.get_ctrl_unit)
  if not ok or unit == nil then
    return nil
  end
  return unit
end

local function _resolve_target_position(unit)
  if not (unit and type(unit.get_position) == "function") then
    return nil
  end
  local ok, pos = pcall(unit.get_position)
  if not ok then
    return nil
  end
  return pos
end

local function _apply_camera_follow(role, target_pos)
  if type(role.set_camera_bind_mode) == "function" then
    pcall(role.set_camera_bind_mode, CAMERA_BIND_MODE_FIXED)
  end
  if type(role.set_camera_lock_position) == "function" then
    pcall(role.set_camera_lock_position, target_pos)
  end
end

function camera_sync.follow_camera(player_id)
  if player_id == nil then
    return false
  end
  local target_unit = _resolve_target_unit(player_id)
  if target_unit == nil then
    return false
  end
  local target_pos = _resolve_target_position(target_unit)
  if target_pos == nil then
    return false
  end
  local roles = runtime_ports.resolve_roles()
  if type(roles) ~= "table" then
    return false
  end
  for _, role in ipairs(roles) do
    if role ~= nil then
      _apply_camera_follow(role, target_pos)
    end
  end
  return true
end

return camera_sync
