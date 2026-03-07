local runtime_constants = require("src.core.config.runtime_constants")
local runtime_event_bridge = require("src.infrastructure.runtime.runtime_event_bridge")
local logger = require("src.core.utils.logger")
local runtime_editor_exports = require("src.core.runtime_facade.runtime_editor_exports")
local vehicle_feature = require("src.game.systems.vehicle.vehicle_feature")
local number_utils = require("src.core.utils.number_utils")
require("Config.runtime_refs")

local runtime_context = {}
local game_api_key = "Game" .. "API"

local current_context = nil

local function _build_vehicle_helper(get_roles, get_game_api)
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

  local function _first_valid_role()
    local roles = nil
    if type(get_roles) == "function" then
      roles = get_roles()
    end
    if type(roles) == "table" then
      for _, role in ipairs(roles) do
        if role ~= nil then
          return role
        end
      end
    end
    local game_api = get_game_api and get_game_api() or nil
    if game_api and game_api.get_all_valid_roles then
      local ok, valid_roles = pcall(game_api.get_all_valid_roles)
      if ok and type(valid_roles) == "table" then
        for _, role in ipairs(valid_roles) do
          if role ~= nil then
            return role
          end
        end
      end
    end
    for role_id = 1, 8 do
      local role = _safe_get_role(role_id)
      if role ~= nil then
        return role
      end
    end
    return nil
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
    if _ensure_valid_role(role_id, "enter") == nil then
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
    if _ensure_valid_role(role_id, "exit") == nil then
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
    if _ensure_valid_role(role_id, "move") == nil then
      return false
    end
    helper.player_id = role_id
    helper.move_direction = dir
    helper.move_time = time
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
    if _ensure_valid_role(role_id, "stop") == nil then
      return false
    end
    helper.player_id = role_id
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

local function _build_change_skin_helper()
  local helper = {
    skin_id = nil,
    target_role_id = nil,
  }

  helper.emit_change_skin = function(role_id, skin_id)
    local resolved_role_id = number_utils.to_integer(role_id)
    local resolved_skin_id = number_utils.to_integer(skin_id)
    if resolved_role_id == nil then
      logger.warn("[Eggy]", "skip skin change event: invalid role_id", tostring(role_id))
      return false
    end
    if resolved_skin_id == nil or resolved_skin_id <= 0 then
      logger.warn("[Eggy]", "skip skin change event: invalid skin_id", tostring(skin_id))
      return false
    end
    helper.target_role_id = resolved_role_id
    helper.skin_id = resolved_skin_id
    runtime_event_bridge.emit_custom_event(
      runtime_constants.eca_event.skin.change,
      {},
      { feature_key = "skin.change" }
    )
    return true
  end

  return helper
end

function runtime_context.new(env)
  return {
    env = env or {},
    roles = nil,
    vehicle_helper = nil,
    camera_helper = nil,
    change_skin_helper = nil,
  }
end

function runtime_context.set_current(ctx)
  current_context = ctx
  return ctx
end

function runtime_context.current()
  return current_context
end

function runtime_context.refresh_roles(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  local game_api = ctx.env[game_api_key]
  if game_api and game_api.get_all_valid_roles then
    ctx.roles = game_api.get_all_valid_roles()
  else
    ctx.roles = {}
  end
  return ctx.roles
end

function runtime_context.install_globals(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  runtime_context.install_environment(ctx)
  runtime_context.install_runtime_helpers(ctx, { install_globals = true })
  runtime_context.install_editor_exports(ctx)
end

function runtime_context.install_environment(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  local lua_api = ctx.env.LuaAPI
  assert(lua_api ~= nil, "missing LuaAPI")
  assert(type(lua_api.call_delay_time) == "function", "missing LuaAPI.call_delay_time")
  assert(type(lua_api.global_register_custom_event) == "function", "missing LuaAPI.global_register_custom_event")
  assert(type(lua_api.global_register_trigger_event) == "function", "missing LuaAPI.global_register_trigger_event")
  assert(type(lua_api.unit_register_custom_event) == "function", "missing LuaAPI.unit_register_custom_event")
  assert(type(lua_api.unit_register_trigger_event) == "function", "missing LuaAPI.unit_register_trigger_event")
  assert(type(lua_api.global_send_custom_event) == "function", "missing LuaAPI.global_send_custom_event")
  return ctx.env
end

function runtime_context.install_runtime_helpers(ctx, opts)
  assert(ctx ~= nil, "missing runtime context")
  opts = opts or {}
  local install_globals = opts.install_globals
  if install_globals == nil then
    install_globals = false
  end
  if not ctx.vehicle_helper then
    local function _resolve_game_api()
      return ctx.env and ctx.env[game_api_key] or nil
    end
    ctx.vehicle_helper = _build_vehicle_helper(function()
      return ctx.roles
    end, _resolve_game_api)
  end
  if not ctx.camera_helper then
    ctx.camera_helper = { target_role_id = 1 }
  end
  if not ctx.change_skin_helper then
    ctx.change_skin_helper = _build_change_skin_helper()
  end

  if not ctx.roles then
    runtime_context.refresh_roles(ctx)
  end
  local helpers = {
    vehicle_helper = ctx.vehicle_helper,
    camera_helper = ctx.camera_helper,
    change_skin_helper = ctx.change_skin_helper,
    roles = ctx.roles,
  }
  if install_globals then
    runtime_context.install_runtime_helper_globals(helpers)
  end
  return helpers
end

function runtime_context.install_runtime_helper_globals(helpers)
  assert(helpers ~= nil, "missing helpers")
  vehicle_helper = helpers.vehicle_helper
  camera_helper = helpers.camera_helper
  change_skin_helper = helpers.change_skin_helper
  all_roles = helpers.roles
  ALLROLES = helpers.roles
  return helpers
end

function runtime_context.install_editor_exports(ctx)
  assert(ctx ~= nil, "missing runtime context")
  runtime_editor_exports.install(ctx)
end

return runtime_context
