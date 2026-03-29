local runtime_event_bridge = require("src.host.event_bridge")
local vehicle_feature = require("src.rules.vehicle")

local M = {}

local function _build_vehicle_helper(get_roles, get_game_api, deps)
  local logger = assert(deps.logger, "missing deps.logger")
  local runtime_constants = assert(deps.runtime_constants, "missing deps.runtime_constants")

  local function _safe_get_role(role_id)
    if role_id == nil then
      return nil
    end
    local game_api = get_game_api and get_game_api() or nil
    if not (game_api and game_api.get_role) then
      return nil
    end
    local ok, role = pcall(game_api.get_role, role_id)
    if not ok then
      return nil
    end
    return role
  end

  local function _first_role_from_list(roles)
    if type(roles) ~= "table" then
      return nil
    end
    for _, role in ipairs(roles) do
      if role ~= nil then
        return role
      end
    end
    return nil
  end

  local function _first_role_from_provider()
    if type(get_roles) ~= "function" then
      return nil
    end
    return _first_role_from_list(get_roles())
  end

  local function _first_role_from_game_api(game_api)
    if not (game_api and game_api.get_all_valid_roles) then
      return nil
    end
    local ok, valid_roles = pcall(game_api.get_all_valid_roles)
    if not ok then
      return nil
    end
    return _first_role_from_list(valid_roles)
  end

  local function _first_role_from_range()
    for role_id = 1, 8 do
      local role = _safe_get_role(role_id)
      if role ~= nil then
        return role
      end
    end
    return nil
  end

  local function _first_valid_role()
    local provider_role = _first_role_from_provider()
    if provider_role ~= nil then
      return provider_role
    end
    local game_api = get_game_api and get_game_api() or nil
    local api_role = _first_role_from_game_api(game_api)
    if api_role ~= nil then
      return api_role
    end
    return _first_role_from_range()
  end

  local function _ensure_valid_role(role_id, action)
    local role = _safe_get_role(role_id)
    if role ~= nil then
      return role
    end
    logger.warn(
      "[Eggy]",
      "skip vehicle event: invalid role",
      tostring(action),
      tostring(role_id)
    )
    return nil
  end

  local function _is_native_move_enabled()
    return runtime_constants.vehicle_move_api_enabled == true
  end

  local function _resolve_character(role)
    if role == nil then
      return nil
    end
    if type(role.get_ctrl_unit) ~= "function" then
      return nil
    end
    local ok, character = pcall(role.get_ctrl_unit)
    if not ok then
      return nil
    end
    return character
  end

  local function _resolve_driving_vehicle(character)
    if character == nil then
      return nil
    end
    local ok, vehicle = pcall(GameAPI.get_driving_vehicle, character)
    if not ok then
      return nil
    end
    return vehicle
  end

  local helper = {
    player_id = nil,
    vehicle_id = nil,
    move_direction = nil,
    move_time = nil,
    set_position = nil,
    active_vehicle_by_player = {},
    needs_enter_wait_by_player = {},
  }

  helper.resolve_role = function(role_id)
    return _safe_get_role(role_id)
  end

  helper.resolve_any_role = function()
    return _first_valid_role()
  end

  helper.emit_vehicle_enter = function(role_id, vehicle_id)
    if not vehicle_feature.is_enabled() then
      return false
    end
    local role = _ensure_valid_role(role_id, "enter")
    if role == nil then
      return false
    end
    helper.player_id = role_id
    helper.vehicle_id = vehicle_id
    if role_id ~= nil then
      helper.active_vehicle_by_player[role_id] = vehicle_id
      helper.needs_enter_wait_by_player[role_id] = true
    end
    runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.vehicle.enter,
      {},
      { feature_key = "vehicle.enter" }
    )
    return true
  end

  helper.emit_vehicle_exit = function(role_id)
    if not vehicle_feature.is_enabled() then
      return false
    end
    local role = _ensure_valid_role(role_id, "exit")
    if role == nil then
      return false
    end
    helper.player_id = role_id
    if role_id ~= nil then
      helper.active_vehicle_by_player[role_id] = nil
      helper.needs_enter_wait_by_player[role_id] = nil
    end
    runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.vehicle.exit,
      {},
      { feature_key = "vehicle.exit" }
    )
    return true
  end

  helper.emit_vehicle_move = function(role_id, dir, time)
    if not vehicle_feature.is_enabled() then
      return false
    end
    local role = _ensure_valid_role(role_id, "move")
    if role == nil then
      return false
    end
    helper.player_id = role_id
    helper.move_direction = dir
    helper.move_time = time
    if _is_native_move_enabled() then
      local character = _resolve_character(role)
      local vehicle = _resolve_driving_vehicle(character)
      if vehicle and type(vehicle.start_move_by_direction) == "function" then
        pcall(vehicle.start_move_by_direction, dir, time)
        return true
      end
    end
    runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.vehicle.move,
      {},
      { feature_key = "vehicle.move" }
    )
    return true
  end

  helper.emit_vehicle_stop = function(role_id)
    if not vehicle_feature.is_enabled() then
      return false
    end
    local role = _ensure_valid_role(role_id, "stop")
    if role == nil then
      return false
    end
    helper.player_id = role_id
    if _is_native_move_enabled() then
      local character = _resolve_character(role)
      local vehicle = _resolve_driving_vehicle(character)
      if vehicle and type(vehicle.stop_move) == "function" then
        pcall(vehicle.stop_move)
        return true
      end
    end
    runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.vehicle.stop,
      {},
      { feature_key = "vehicle.stop" }
    )
    return true
  end

  helper.emit_vehicle_set_position = function(role_id, pos)
    if not vehicle_feature.is_enabled() then
      return false
    end
    if _ensure_valid_role(role_id, "set_position") == nil then
      return false
    end
    helper.player_id = role_id
    helper.set_position = pos
    runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.vehicle.set_position,
      {},
      { feature_key = "vehicle.set_position" }
    )
    return true
  end

  helper.consume_enter_delay = function(role_id, vehicle_id)
    if not vehicle_feature.is_enabled() then
      return 0
    end
    if role_id == nil or vehicle_id == nil then
      return 0
    end
    local active_vehicle = helper.active_vehicle_by_player[role_id]
    if active_vehicle ~= vehicle_id then
      helper.emit_vehicle_enter(role_id, vehicle_id)
    end
    if helper.needs_enter_wait_by_player[role_id] then
      helper.needs_enter_wait_by_player[role_id] = nil
      return runtime_constants.vehicle_enter_delay or 0
    end
    return 0
  end

  return helper
end

function M.build_helper(get_roles, get_game_api, deps)
  return _build_vehicle_helper(get_roles, get_game_api, deps or {})
end

return M
