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

local function _safe_call_method(state, obj, key, log_key, log_prefix)
  if type(obj[key]) ~= "function" then return nil end
  local ok, result = pcall(obj[key])
  if not ok then
    runtime_state.log_once(state, "warn", log_key, "camera_sync", log_prefix, tostring(result))
    return nil
  end
  return result
end

local function _resolve_unit_position(state, role)
  if role == nil then return nil end
  local unit = _safe_call_method(state, role, "get_ctrl_unit", "camera_sync:get_ctrl_unit_failed", "resolve unit failed:")
  if unit == nil then return nil end
  return _safe_call_method(state, unit, "get_position", "camera_sync:get_position_failed", "resolve unit position failed:")
end

local function _resolve_followed_unit_live_position(state, player_id)
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

local function _resolve_camera_local_role(state)
  local role_id = _resolve_camera_local_role_id(state)
  if role_id == nil then return nil, nil end
  return runtime_ports.resolve_role(role_id), role_id
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

  local local_role, local_role_id = _resolve_camera_local_role(state)
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
  local local_role, local_role_id = _resolve_camera_local_role(state)
  if local_role == nil or target_id == local_role_id then
    return false
  end
  local target_pos = _resolve_follow_target_position(state, target_id)
  return _lock_camera_to_target_position(state, local_role, target_pos)
end

function camera_sync.pan_camera_to_position(state, target_pos)
  if target_pos == nil then
    return false
  end
  local local_role = _resolve_camera_local_role(state)
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
  turn_runtime.last_follow_player_id = nil
  return true
end

return camera_sync

--[[ mutate4lua-manifest
version=2
projectHash=031ff44679a86e95
scope.0.id=chunk:src/ui/ports/ui_sync/camera.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=201
scope.0.semanticHash=52777d2e56462a39
scope.0.lastMutatedAt=2026-05-29T14:22:54Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=14
scope.0.lastMutationKilled=14
scope.1.id=function:_safe_call_method:38
scope.1.kind=function
scope.1.startLine=38
scope.1.endLine=46
scope.1.semanticHash=2d8a7bded94b7ac2
scope.1.lastMutatedAt=2026-05-29T14:22:54Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_resolve_unit_position:48
scope.2.kind=function
scope.2.startLine=48
scope.2.endLine=53
scope.2.semanticHash=33bc50613da50cc7
scope.2.lastMutatedAt=2026-05-29T14:22:54Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_resolve_followed_unit_live_position:55
scope.3.kind=function
scope.3.startLine=55
scope.3.endLine=65
scope.3.semanticHash=8d7f5566f5efa1d4
scope.3.lastMutatedAt=2026-05-29T14:22:54Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_resolve_follow_target_position:67
scope.4.kind=function
scope.4.startLine=67
scope.4.endLine=81
scope.4.semanticHash=306041acfabc5a25
scope.4.lastMutatedAt=2026-05-29T14:22:54Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:_resolve_current_player_id:83
scope.5.kind=function
scope.5.startLine=83
scope.5.endLine=90
scope.5.semanticHash=1dbe4507b57a8bb8
scope.5.lastMutatedAt=2026-05-29T14:22:54Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=13
scope.5.lastMutationKilled=13
scope.6.id=function:_resolve_camera_local_role_id:92
scope.6.kind=function
scope.6.startLine=92
scope.6.endLine=95
scope.6.semanticHash=688b77cd917795dc
scope.6.lastMutatedAt=2026-05-29T14:22:54Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=5
scope.6.lastMutationKilled=5
scope.7.id=function:_resolve_camera_local_role:97
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=101
scope.7.semanticHash=abb77e2b2321806f
scope.7.lastMutatedAt=2026-05-29T14:22:54Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:_lock_camera_to_target_position:103
scope.8.kind=function
scope.8.startLine=103
scope.8.endLine=117
scope.8.semanticHash=06bec805541521c5
scope.8.lastMutatedAt=2026-05-29T14:22:54Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=12
scope.8.lastMutationKilled=12
scope.9.id=function:_reset_camera_to_self:119
scope.9.kind=function
scope.9.startLine=119
scope.9.endLine=128
scope.9.semanticHash=0fbdc308eb64662e
scope.9.lastMutatedAt=2026-05-29T14:22:54Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=9
scope.9.lastMutationKilled=9
scope.10.id=function:camera_sync.follow_camera:130
scope.10.kind=function
scope.10.startLine=130
scope.10.endLine=159
scope.10.semanticHash=e674b5f6a5a63064
scope.10.lastMutatedAt=2026-05-29T14:22:54Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=18
scope.10.lastMutationKilled=18
scope.11.id=function:camera_sync.sync_camera_position:161
scope.11.kind=function
scope.11.startLine=161
scope.11.endLine=173
scope.11.semanticHash=d5192e7c3b475285
scope.11.lastMutatedAt=2026-05-29T14:22:54Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=12
scope.11.lastMutationKilled=12
scope.12.id=function:camera_sync.pan_camera_to_position:175
scope.12.kind=function
scope.12.startLine=175
scope.12.endLine=189
scope.12.semanticHash=66ba27893d44492e
scope.12.lastMutatedAt=2026-05-29T14:22:54Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=8
scope.12.lastMutationKilled=8
scope.13.id=function:camera_sync.release_target_pan:191
scope.13.kind=function
scope.13.startLine=191
scope.13.endLine=198
scope.13.semanticHash=9a97de9baa5b03ff
scope.13.lastMutatedAt=2026-05-29T14:22:54Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=4
scope.13.lastMutationKilled=4
]]
