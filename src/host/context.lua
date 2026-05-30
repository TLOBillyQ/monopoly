local synthetic_actor_registry = require("src.host.synthetic_actor_registry")
require("src.config.content.runtime_refs")

local runtime_context = {}
local game_api_key = "Game" .. "API"

local current_context = nil

local function _resolve_game_api_instance(get_game_api)
  if type(get_game_api) ~= "function" then
    return nil
  end
  return get_game_api()
end

local function _resolve_game_api_roles(get_game_api)
  local game_api = _resolve_game_api_instance(get_game_api)
  if not (game_api and type(game_api.get_all_valid_roles) == "function") then
    return {}
  end
  local ok, valid_roles = pcall(game_api.get_all_valid_roles)
  if not ok or type(valid_roles) ~= "table" then
    return {}
  end
  return valid_roles
end

function runtime_context.new(env)
  return {
    env = env or {},
    roles = nil,
    camera_helper = nil,
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

local function _refresh_roles(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  ctx.roles = _resolve_game_api_roles(function()
    return ctx.env and ctx.env[game_api_key] or nil
  end)
  return ctx.roles
end

function runtime_context.install_globals(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  runtime_context.install_environment(ctx)
  runtime_context.install_runtime_helpers(ctx, { install_globals = true })
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
  if not ctx.camera_helper then
    ctx.camera_helper = require("src.host.camera").new(ctx.env)
  end
  if not ctx.synthetic_actor_registry then
    ctx.synthetic_actor_registry = synthetic_actor_registry.new(ctx.env)
  end

  if not ctx.roles then
    _refresh_roles(ctx)
  end
  local helpers = {
    camera_helper = ctx.camera_helper,
    roles = ctx.roles,
  }
  if install_globals then
    runtime_context.install_runtime_helper_globals(helpers)
  end
  return helpers
end

function runtime_context.install_runtime_helper_globals(helpers)
  assert(helpers ~= nil, "missing helpers")
  camera_helper = helpers.camera_helper
  all_roles = helpers.roles
  ALLROLES = helpers.roles
  return helpers
end

return runtime_context

--[[ mutate4lua-manifest
version=2
projectHash=7e4d6cf432a96481
scope.0.id=chunk:src/host/context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=109
scope.0.semanticHash=28ea142418c5bb48
scope.1.id=function:_resolve_game_api_instance:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=14
scope.1.semanticHash=49a395b84142025d
scope.2.id=function:_resolve_game_api_roles:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=26
scope.2.semanticHash=4bc1e98c9248a7d3
scope.3.id=function:runtime_context.new:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=35
scope.3.semanticHash=21472f8f753c912a
scope.4.id=function:runtime_context.set_current:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=40
scope.4.semanticHash=c6272300113244ba
scope.5.id=function:runtime_context.current:42
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=44
scope.5.semanticHash=8d1f470238ae4491
scope.6.id=function:anonymous@48:48
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=50
scope.6.semanticHash=c3ecd5ff731c4de1
scope.7.id=function:_refresh_roles:46
scope.7.kind=function
scope.7.startLine=46
scope.7.endLine=52
scope.7.semanticHash=e6b7d29a2c40603d
scope.8.id=function:runtime_context.install_globals:54
scope.8.kind=function
scope.8.startLine=54
scope.8.endLine=58
scope.8.semanticHash=16ac89bbea30c944
scope.9.id=function:runtime_context.install_environment:60
scope.9.kind=function
scope.9.startLine=60
scope.9.endLine=71
scope.9.semanticHash=30110c308b0b7f02
scope.10.id=function:runtime_context.install_runtime_helpers:73
scope.10.kind=function
scope.10.startLine=73
scope.10.endLine=98
scope.10.semanticHash=37e3f9dade64d256
scope.11.id=function:runtime_context.install_runtime_helper_globals:100
scope.11.kind=function
scope.11.startLine=100
scope.11.endLine=106
scope.11.semanticHash=acae73be2ad6fbf3
]]
