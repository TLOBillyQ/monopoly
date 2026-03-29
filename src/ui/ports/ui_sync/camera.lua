local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_state = require("src.ui.state")
local logger = require("src.core.utils.logger")

local camera_sync = {}
local _warned = {}

local function _warn_once(key, ...)
  if _warned[key] then
    return
  end
  _warned[key] = true
  logger.warn("camera_sync", ...)
end

local function _resolve_unit_position(role)
  if role == nil then
    return nil
  end
  if type(role.get_ctrl_unit) ~= "function" then
    return nil
  end
  local ok, unit = pcall(function()
    return role.get_ctrl_unit()
  end)
  if not ok or unit == nil then
    if not ok then
      _warn_once("get_ctrl_unit_failed", "resolve unit failed:", tostring(unit))
    end
    return nil
  end
  if type(unit.get_position) ~= "function" then
    return nil
  end
  local pos_ok, pos = pcall(function()
    return unit.get_position()
  end)
  if not pos_ok then
    _warn_once("get_position_failed", "resolve unit position failed:", tostring(pos))
    return nil
  end
  return pos
end

local function _get_camera_direction_safe(role)
  if type(role.get_camera_direction) ~= "function" then
    return nil
  end
  local ok, dir = pcall(function()
    return role.get_camera_direction()
  end)
  if not ok or dir == nil then
    return nil
  end
  return dir
end

local function _lock_camera_to_target(local_role, target_role, ctx_info)
   local pos = _resolve_unit_position(target_role)
   if pos == nil then
     logger.warn("[CAMERA_INVESTIGATE] _lock_camera_to_target: cannot resolve target position", ctx_info or "")
     return false
   end
   logger.warn("[CAMERA_INVESTIGATE] _lock_camera_to_target: " .. (ctx_info or "") .. " target_pos=" .. tostring(pos))

   local dir_before = _get_camera_direction_safe(local_role)
   logger.warn("[CAMERA_INVESTIGATE] camera direction BEFORE lock: " .. tostring(dir_before))

   if type(local_role.set_camera_lock_position) ~= "function" then
     logger.warn("[CAMERA_INVESTIGATE] set_camera_lock_position not available")
     return false
  end
  local ok, err = pcall(function()
    return local_role.set_camera_lock_position(pos)
  end)
   if not ok then
     _warn_once("set_camera_lock_position_failed", "set_camera_lock_position failed:", tostring(err))
     logger.warn("[CAMERA_INVESTIGATE] set_camera_lock_position failed:", tostring(err))
   else
     logger.warn("[CAMERA_INVESTIGATE] set_camera_lock_position succeeded")
  end

   local dir_after = _get_camera_direction_safe(local_role)
   logger.warn("[CAMERA_INVESTIGATE] camera direction AFTER lock: " .. tostring(dir_after))

   if dir_after ~= nil then
     logger.warn("[CAMERA_INVESTIGATE] dir_after components: x=" .. tostring(dir_after.x) .. " y=" .. tostring(dir_after.y) .. " z=" .. tostring(dir_after.z))
   end

   return ok == true
end

local function _reset_camera_to_self(local_role)
  if type(local_role.reset_camera) ~= "function" then
    return false
  end
  local ok, err = pcall(function()
    return local_role.reset_camera(true, true, true, true)
  end)
  if not ok then
    _warn_once("reset_camera_failed", "reset_camera failed:", tostring(err))
  end
  return ok == true
end

function camera_sync.follow_camera(state, player_id)
   logger.warn("[CAMERA_INVESTIGATE] follow_camera called: player_id=" .. tostring(player_id))
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
   logger.warn("[CAMERA_INVESTIGATE] local_role_id=" .. tostring(local_role_id))
  if local_role_id == nil then
    return false
  end
   local local_role = runtime_ports.resolve_role(local_role_id)
   if local_role == nil then
     logger.warn("[CAMERA_INVESTIGATE] cannot resolve local_role for id=" .. tostring(local_role_id))
    return false
  end

   if player_id == local_role_id then
     logger.warn("[CAMERA_INVESTIGATE] path: SELF (player_id == local_role_id), calling reset_camera")
    return _reset_camera_to_self(local_role)
  end

   logger.warn("[CAMERA_INVESTIGATE] path: OTHER (player_id ~= local_role_id), will reset then lock")
   local reset_ok = _reset_camera_to_self(local_role)
   logger.warn("[CAMERA_INVESTIGATE] reset_camera result: " .. tostring(reset_ok))

   local target_role = runtime_ports.resolve_role(player_id)
   if target_role == nil then
     logger.warn("[CAMERA_INVESTIGATE] cannot resolve target_role for id=" .. tostring(player_id))
    return false
  end

  local ctx_info = "local=" .. tostring(local_role_id) .. " target=" .. tostring(player_id)
  return _lock_camera_to_target(local_role, target_role, ctx_info)
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
  local ctx_info = "[sync] local=" .. tostring(local_role_id) .. " target=" .. tostring(target_id)
  return _lock_camera_to_target(local_role, target_role, ctx_info)
end

return camera_sync
