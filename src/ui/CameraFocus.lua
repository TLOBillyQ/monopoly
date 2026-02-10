local runtime_constants = require("Config.RuntimeConstants")

local camera_focus = {}

local function _resolve_tile_pos(state, tile_index)
  assert(state ~= nil, "missing state")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local tiles = assert(scene.tiles, "missing scene.tiles")
  local tile = assert(tiles[tile_index], "missing tile unit: " .. tostring(tile_index))
  assert(tile.get_position ~= nil, "missing tile.get_position: " .. tostring(tile_index))
  return tile.get_position()
end

local function _current_turn_player_id(state)
  if not state or not state.game or not state.game.turn or not state.game.players then
    return nil
  end
  local idx = state.game.turn.current_player_index
  local player = idx and state.game.players[idx] or nil
  return player and player.id or nil
end

local function _trigger_follow_player(role_id)
  if not role_id then
    return false
  end
  if not (camera_helper and runtime_constants and runtime_constants.eca_event and runtime_constants.eca_event.camera
    and runtime_constants.eca_event.camera.follow and TriggerCustomEvent) then
    return false
  end
  camera_helper.target_role_id = role_id
  TriggerCustomEvent(runtime_constants.eca_event.camera.follow, {})
  return true
end

local function _collect_camera_roles(state)
  local roles = {}
  if type(all_roles) == "table" and #all_roles > 0 then
    for _, role in ipairs(all_roles) do
      roles[#roles + 1] = role
    end
    return roles
  end
  if GameAPI and GameAPI.get_all_valid_roles then
    local ok, list = pcall(GameAPI.get_all_valid_roles)
    if ok and type(list) == "table" and #list > 0 then
      return list
    end
  end
  if GameAPI and GameAPI.get_role then
    local turn_player_id = _current_turn_player_id(state) or 1
    local ok, role = pcall(GameAPI.get_role, turn_player_id)
    if ok and role then
      roles[#roles + 1] = role
    end
  end
  return roles
end

local function _set_roles_bind_mode(roles, mode)
  local applied = false
  for _, role in ipairs(roles) do
    if role and role.set_camera_bind_mode then
      local ok = pcall(function()
        role.set_camera_bind_mode(mode)
      end)
      if ok then
        applied = true
      end
    end
  end
  return applied
end

local function _lock_camera_to_tile(state, tile_index)
  if not (Enums and Enums.CameraBindMode and Enums.CameraBindMode.BIND) then
    return false
  end
  local pos = _resolve_tile_pos(state, tile_index)
  local roles = _collect_camera_roles(state)
  if #roles == 0 then
    return false
  end
  local locked = false
  local mode_applied = _set_roles_bind_mode(roles, Enums.CameraBindMode.BIND)
  for _, role in ipairs(roles) do
    if role and role.set_camera_lock_position then
      local ok = pcall(function()
        role.set_camera_lock_position(pos)
      end)
      if ok then
        locked = true
      end
    end
  end
  return mode_applied and locked
end

local function _restore_track_mode(state)
  if not (Enums and Enums.CameraBindMode and Enums.CameraBindMode.TRACK) then
    return false
  end
  local roles = _collect_camera_roles(state)
  if #roles == 0 then
    return false
  end
  return _set_roles_bind_mode(roles, Enums.CameraBindMode.TRACK)
end

local function _restore_camera_focus(state, token)
  if not state then
    return
  end
  if (state.camera_focus_token or 0) ~= token then
    return
  end
  if state.camera_focus_lock_mode == "tile" then
    _restore_track_mode(state)
  end
  state.camera_focus_active = false
  state.camera_focus_lock_mode = nil
  local restore_role_id = _current_turn_player_id(state) or state.camera_focus_restore_role_id
  state.camera_focus_restore_role_id = restore_role_id
  if restore_role_id then
    _trigger_follow_player(restore_role_id)
  end
end

function camera_focus.begin(state, anim, duration)
  if not state or not anim then
    return
  end
  state.camera_focus_token = (state.camera_focus_token or 0) + 1
  local token = state.camera_focus_token
  state.camera_focus_restore_role_id = _current_turn_player_id(state)
  state.camera_focus_active = false
  state.camera_focus_lock_mode = nil
  local focused = false
  if anim.focus_target_player_id then
    focused = _trigger_follow_player(anim.focus_target_player_id)
    if focused then
      state.camera_focus_active = true
      state.camera_focus_lock_mode = "player"
    end
  elseif anim.focus_target_tile_index then
    focused = _lock_camera_to_tile(state, anim.focus_target_tile_index)
    if focused then
      state.camera_focus_active = true
      state.camera_focus_lock_mode = "tile"
    end
  end
  if not focused then
    return
  end
  if duration and duration > 0 then
    SetTimeOut(duration, function()
      _restore_camera_focus(state, token)
    end)
    return
  end
  _restore_camera_focus(state, token)
end

return camera_focus
