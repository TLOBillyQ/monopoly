local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
local runtime_env_bindings = require("src.core.RuntimeEnvBindings")
local runtime_editor_exports = require("src.core.RuntimeEditorExports")
local vehicle_feature = require("src.game.vehicle.VehicleFeature")
require("Config.RuntimeRefs")

local runtime_context = {}

local current_context = nil

local function _build_vehicle_helper()
  local function _safe_get_role(role_id)
    if role_id == nil then
      return nil
    end
    if not (GameAPI and GameAPI.get_role) then
      return nil
    end
    local ok, role = pcall(GameAPI.get_role, role_id)
    if not ok then
      return nil
    end
    return role
  end

  local function _first_valid_role()
    local roles = all_roles
    if type(roles) == "table" then
      for _, role in ipairs(roles) do
        if role ~= nil then
          return role
        end
      end
    end
    if GameAPI and GameAPI.get_all_valid_roles then
      local ok, valid_roles = pcall(GameAPI.get_all_valid_roles)
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

  helper.forward_eca_event_enter = function(role_id, vehicle_id)
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
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.enter, {})
    return true
  end

  helper.forward_eca_event_exit = function(role_id)
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
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.exit, {})
    return true
  end

  helper.forward_eca_event_move = function(role_id, dir, time)
    if not vehicle_feature.is_enabled() then
      return false
    end
    if _ensure_valid_role(role_id, "move") == nil then
      return false
    end
    helper.player_id = role_id
    helper.move_direction = dir
    helper.move_time = time
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.move, {})
    return true
  end

  helper.forward_eca_event_stop = function(role_id)
    if not vehicle_feature.is_enabled() then
      return false
    end
    if _ensure_valid_role(role_id, "stop") == nil then
      return false
    end
    helper.player_id = role_id
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.stop, {})
    return true
  end

  helper.forward_eca_event_set_position = function(role_id, pos)
    if not vehicle_feature.is_enabled() then
      return false
    end
    if _ensure_valid_role(role_id, "set_position") == nil then
      return false
    end
    helper.player_id = role_id
    helper.set_position = pos
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.set_position, {})
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
      helper.forward_eca_event_enter(role_id, vehicle_id)
    end
    if helper.needs_enter_wait_by_player[role_id] then
      helper.needs_enter_wait_by_player[role_id] = nil
      return runtime_constants.vehicle_enter_delay or 0
    end
    return 0
  end

  return helper
end

function runtime_context.new(env)
  return {
    env = env or {},
    roles = nil,
    vehicle_helper = nil,
    camera_helper = nil,
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
  local game_api = ctx.env.GameAPI
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
  runtime_context.install_runtime_helpers(ctx)
  runtime_context.install_editor_exports(ctx)
end

function runtime_context.install_environment(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  runtime_env_bindings.install(ctx.env)
end

function runtime_context.install_runtime_helpers(ctx)
  assert(ctx ~= nil, "missing runtime context")
  if not ctx.vehicle_helper then
    ctx.vehicle_helper = _build_vehicle_helper()
  end
  if not ctx.camera_helper then
    ctx.camera_helper = { target_role_id = 1 }
  end

  vehicle_helper = ctx.vehicle_helper
  camera_helper = ctx.camera_helper

  if not ctx.roles then
    runtime_context.refresh_roles(ctx)
  end
  all_roles = ctx.roles
  ALLROLES = ctx.roles
end

function runtime_context.install_editor_exports(ctx)
  assert(ctx ~= nil, "missing runtime context")
  runtime_editor_exports.install(ctx)
end

return runtime_context
