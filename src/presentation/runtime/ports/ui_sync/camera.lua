local runtime_ports = require("src.core.ports.runtime_ports")
local logger = require("src.core.utils.logger")

local camera_sync = {}

local CAMERA_BIND_MODE_FIXED = 1

local CAMERA_DIST = 50
local CAMERA_FOV = 40
local CAMERA_PITCH = 60
local CAMERA_YAW = -80
local CAMERA_PITCH_MIN = 60
local CAMERA_PITCH_MAX = 60
local CAMERA_OBSERVER_HEIGHT = 1
local CAMERA_HORIZONTAL_OFFSET = 0
local CAMERA_DRAG_SPEED = 70

local PROP_DIST = 7
local PROP_FOV = 8
local PROP_PITCH_MAX = 9
local PROP_PITCH_MIN = 10
local PROP_OBSERVER_HEIGHT = 11
local PROP_HORIZONTAL_OFFSET = 12
local PROP_PITCH = 15
local PROP_YAW = 16
local PROP_DRAG_SPEED = 25

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

local function _apply_camera_init(role)
  if type(role.set_camera_property) == "function" then
    pcall(role.set_camera_property, PROP_DIST, CAMERA_DIST)
    pcall(role.set_camera_property, PROP_FOV, CAMERA_FOV)
    pcall(role.set_camera_property, PROP_PITCH, CAMERA_PITCH)
    pcall(role.set_camera_property, PROP_YAW, CAMERA_YAW)
    pcall(role.set_camera_property, PROP_PITCH_MIN, CAMERA_PITCH_MIN)
    pcall(role.set_camera_property, PROP_PITCH_MAX, CAMERA_PITCH_MAX)
    pcall(role.set_camera_property, PROP_OBSERVER_HEIGHT, CAMERA_OBSERVER_HEIGHT)
    pcall(role.set_camera_property, PROP_HORIZONTAL_OFFSET, CAMERA_HORIZONTAL_OFFSET)
    pcall(role.set_camera_property, PROP_DRAG_SPEED, CAMERA_DRAG_SPEED)
  end
  if type(role.set_camera_draggable) == "function" then
    pcall(role.set_camera_draggable, true)
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

function camera_sync.init_camera()
  local roles = runtime_ports.resolve_roles()
  if type(roles) ~= "table" then
    return false
  end
  for _, role in ipairs(roles) do
    if role ~= nil then
      _apply_camera_init(role)
    end
  end
  return true
end

return camera_sync
