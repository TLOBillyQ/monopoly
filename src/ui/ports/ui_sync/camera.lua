local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_state = require("src.ui.state")

local camera_sync = {}

local function _resolve_unit_position(role)
  if role == nil then
    return nil
  end
  if type(role.get_ctrl_unit) ~= "function" then
    return nil
  end
  local ok, unit = pcall(role.get_ctrl_unit, role)
  if not ok or unit == nil then
    return nil
  end
  if type(unit.get_position) ~= "function" then
    return nil
  end
  local pos_ok, pos = pcall(unit.get_position)
  if not pos_ok then
    return nil
  end
  return pos
end

local function _lock_camera_to_target(local_role, target_role)
  local pos = _resolve_unit_position(target_role)
  if pos == nil then
    return false
  end
  if type(local_role.set_camera_lock_position) ~= "function" then
    return false
  end
  local ok = pcall(local_role.set_camera_lock_position, pos)
  return ok == true
end

local function _reset_camera_to_self(local_role)
  if type(local_role.reset_camera) ~= "function" then
    return false
  end
  local ok = pcall(local_role.reset_camera, true, true, true, true)
  return ok == true
end

function camera_sync.follow_camera(state, player_id)
  if player_id == nil then
    return false
  end
  local camera = runtime_ports.resolve_camera_helper()
  if camera then
    camera.target_role_id = player_id
  end
  if camera and type(camera.follow) == "function" then
    camera.follow(player_id)
  end

  local local_role_id = state and runtime_state.get_local_actor_role_id(state) or nil
  if local_role_id == nil then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end

  if player_id == local_role_id then
    return _reset_camera_to_self(local_role)
  end

  local target_role = runtime_ports.resolve_role(player_id)
  return _lock_camera_to_target(local_role, target_role)
end

function camera_sync.sync_camera_position(state)
  local camera = runtime_ports.resolve_camera_helper()
  local target_id = camera and camera.target_role_id or nil
  if target_id == nil then
    return false
  end
  local local_role_id = state and runtime_state.get_local_actor_role_id(state) or nil
  if local_role_id == nil or target_id == local_role_id then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end
  local target_role = runtime_ports.resolve_role(target_id)
  return _lock_camera_to_target(local_role, target_role)
end

return camera_sync
