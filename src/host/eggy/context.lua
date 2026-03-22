local runtime_constants = require("src.config.gameplay.runtime_constants")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local logger = require("src.core.utils.logger")
local runtime_editor_exports = require("src.state.state_access.runtime_editor_exports")
local number_utils = require("src.core.utils.number_utils")
local synthetic_actor_registry = require("src.host.eggy.synthetic_actor_registry")
require("src.config.content.runtime_refs")

local runtime_context = {}
local game_api_key = "Game" .. "API"

local current_context = nil

local function _build_noop_vehicle_helper(get_roles, get_game_api)
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

  return {
    player_id = nil,
    vehicle_id = nil,
    move_direction = nil,
    move_time = nil,
    set_position = nil,
    active_vehicle_by_player = {},
    needs_enter_wait_by_player = {},
    resolve_role = _safe_get_role,
    resolve_any_role = function()
      local provider_roles = type(get_roles) == "function" and get_roles() or nil
      local first = _first_role_from_list(provider_roles)
      if first ~= nil then
        return first
      end
      local game_api = get_game_api and get_game_api() or nil
      if game_api and type(game_api.get_all_valid_roles) == "function" then
        local ok, valid_roles = pcall(game_api.get_all_valid_roles)
        if ok then
          return _first_role_from_list(valid_roles)
        end
      end
      return nil
    end,
    emit_vehicle_enter = function() return false end,
    emit_vehicle_exit = function() return false end,
    emit_vehicle_move = function() return false end,
    emit_vehicle_stop = function() return false end,
    emit_vehicle_set_position = function() return false end,
    consume_enter_delay = function() return 0 end,
  }
end

local function _resolve_vehicle_helper_builder()
  if _G and _G.MONOPOLY_BUILD_MODE == "release" then
    return function(get_roles, get_game_api)
      return _build_noop_vehicle_helper(get_roles, get_game_api)
    end
  end
  return function(get_roles, get_game_api)
    return require("src.state.state_access.vehicle_runtime_source").build_helper(get_roles, get_game_api, {
      logger = logger,
      runtime_constants = runtime_constants,
      runtime_event_bridge = runtime_event_bridge,
    }, _G)
  end
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
    synthetic_actor_registry = nil,
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
    ctx.vehicle_helper = _resolve_vehicle_helper_builder()(function()
      return ctx.roles
    end, _resolve_game_api)
  end
  if not ctx.camera_helper then
    ctx.camera_helper = { target_role_id = 1 }
  end
  if not ctx.change_skin_helper then
    ctx.change_skin_helper = _build_change_skin_helper()
  end
  if not ctx.synthetic_actor_registry then
    ctx.synthetic_actor_registry = synthetic_actor_registry.new(ctx.env)
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
