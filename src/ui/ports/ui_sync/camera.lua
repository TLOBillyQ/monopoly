local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local camera_follow = require("src.config.gameplay.camera_follow")
local unit_position = require("src.ui.render.unit_position")

local camera_sync = {}

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
  local props = _camera_props
  if type(local_role.set_camera_property) ~= "function" then
    runtime_state.log_once(state, "warn", "camera_sync:set_camera_property_unavailable", "camera_sync", "set_camera_property not available on role")
    return
  end
  for _, entry in ipairs(props) do
    local prop, value = entry[1], entry[2]
    local ok, err = pcall(local_role.set_camera_property, prop, value)
    if not ok then
      runtime_state.log_once(state, "warn", "camera_sync:set_camera_property_" .. tostring(prop), "camera_sync", "set_camera_property(" .. tostring(prop) .. ") failed:", tostring(err))
    end
  end
end

local function _resolve_unit_position(state, role)
  if role == nil then
    return nil
  end
  if type(role.get_ctrl_unit) ~= "function" then
    return nil
  end
  local ok, unit = pcall(role.get_ctrl_unit)
  if not ok or unit == nil then
    if not ok then
      runtime_state.log_once(state, "warn", "camera_sync:get_ctrl_unit_failed", "camera_sync", "resolve unit failed:", tostring(unit))
    end
    return nil
  end
  if type(unit.get_position) ~= "function" then
    return nil
  end
  local pos_ok, pos = pcall(unit.get_position)
  if not pos_ok then
    runtime_state.log_once(state, "warn", "camera_sync:get_position_failed", "camera_sync", "resolve unit position failed:", tostring(pos))
    return nil
  end
  return pos
end

local function _resolve_followed_unit_live_position(state, player_id)
  -- Prefer the followed player's live (frame-interpolated) world position so
  -- the camera follows the unit smoothly mid-walk, instead of snapping to the
  -- next tile destination published by the move animation. The unit handle's
  -- get_position() is updated continuously by the host during
  -- start_move_by_direction, which gives the camera free smooth follow.
  local board_scene = state and state.board_scene or nil
  if board_scene == nil then
    return nil
  end
  local units_by_player_id = board_scene.units_by_player_id
  if type(units_by_player_id) ~= "table" then
    return nil
  end
  return unit_position.read_unit_position(units_by_player_id[player_id])
end

local function _resolve_follow_target_position(state, player_id)
  local live_pos = _resolve_followed_unit_live_position(state, player_id)
  if live_pos ~= nil then
    return live_pos
  end
  local followed_pos = runtime_state.get_follow_target_position(state, player_id)
  if followed_pos ~= nil then
    return followed_pos
  end
  local target_role = runtime_ports.resolve_role(player_id)
  if target_role == nil then
    return nil
  end
  return _resolve_unit_position(state, target_role)
end

local function _resolve_current_player_id(state)
  local game = state and state.game or nil
  local turn = game and game.turn or nil
  local players = game and game.players or nil
  local current_index = turn and turn.current_player_index or nil
  local current_player = current_index and players and players[current_index] or nil
  return current_player and current_player.id or nil
end

local function _resolve_camera_local_role_id(state)
  return (state and runtime_state.get_local_actor_role_id(state) or nil)
    or _resolve_current_player_id(state)
end

local function _lock_camera_to_target_position(state, local_role, target_pos)
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
   end

   return ok == true
end

local function _reset_camera_to_self(state, local_role)
  if type(local_role.reset_camera) ~= "function" then
    return false
  end
  local ok, err = pcall(local_role.reset_camera, true, true, true, true)
  if not ok then
    runtime_state.log_once(state, "warn", "camera_sync:reset_camera_failed", "camera_sync", "reset_camera failed:", tostring(err))
  end
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

  local local_role_id = _resolve_camera_local_role_id(state)
  if local_role_id == nil then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end

  if player_id == local_role_id then
    return _reset_camera_to_self(state, local_role)
  end

  _reset_camera_to_self(state, local_role)

  local target_pos = _resolve_follow_target_position(state, player_id)
  if target_pos == nil then
    return false
  end

  return _lock_camera_to_target_position(state, local_role, target_pos)
end


function camera_sync.sync_camera_position(state)
  local camera = runtime_ports.resolve_camera_helper()
  local target_id = camera and camera.target_role_id or nil
  if target_id == nil then
    return false
  end
  local local_role_id = _resolve_camera_local_role_id(state)
  if local_role_id == nil or target_id == local_role_id then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end
  local target_pos = _resolve_follow_target_position(state, target_id)
  return _lock_camera_to_target_position(state, local_role, target_pos)
end

function camera_sync.pan_camera_to_position(state, target_pos)
  if target_pos == nil then
    return false
  end
  local local_role_id = _resolve_camera_local_role_id(state)
  if local_role_id == nil then
    return false
  end
  local local_role = runtime_ports.resolve_role(local_role_id)
  if local_role == nil then
    return false
  end
  local camera = runtime_ports.resolve_camera_helper()
  if camera then
    camera.target_role_id = nil
  end
  _reset_camera_to_self(state, local_role)
  return _lock_camera_to_target_position(state, local_role, target_pos)
end

function camera_sync.release_target_pan(state)
  if state == nil then
    return false
  end
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  if turn_runtime == nil then
    return false
  end
  turn_runtime.last_follow_player_id = nil
  return true
end

return camera_sync
