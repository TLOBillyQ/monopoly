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

local _required_lua_api_methods = {
  "call_delay_time",
  "global_register_custom_event",
  "global_register_trigger_event",
  "global_unregister_trigger_event",
  "unit_register_custom_event",
  "unit_register_trigger_event",
  "global_send_custom_event",
}

local function _validate_lua_api_methods(lua_api)
  assert(lua_api ~= nil, "missing LuaAPI")
  for _, name in ipairs(_required_lua_api_methods) do
    assert(type(lua_api[name]) == "function", "missing LuaAPI." .. name)
  end
end

function runtime_context.install_environment(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  local lua_api = ctx.env.LuaAPI
  _validate_lua_api_methods(lua_api)
  return ctx.env
end

local function _ensure_runtime_helper_fields(ctx)
  if not ctx.camera_helper then
    ctx.camera_helper = require("src.host.camera").new(ctx.env)
  end
  if not ctx.synthetic_actor_registry then
    ctx.synthetic_actor_registry = synthetic_actor_registry.new(ctx.env)
  end
  if not ctx.roles then
    _refresh_roles(ctx)
  end
end

function runtime_context.install_runtime_helpers(ctx, opts)
  assert(ctx ~= nil, "missing runtime context")
  opts = opts or {}
  _ensure_runtime_helper_fields(ctx)
  local helpers = {
    camera_helper = ctx.camera_helper,
    roles = ctx.roles,
  }
  if opts.install_globals then
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
version=4
projectHash=e089607aa636f993
scope.0.id=chunk:src/host/context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=081d182c92e23547
scope.1.id=function:_resolve_game_api_instance
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=14
scope.1.semanticHash=c5503c7e3af71e61
scope.2.id=function:_resolve_game_api_roles
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=26
scope.2.semanticHash=dcbfbcdece3666e6
scope.3.id=function:runtime_context.new
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=35
scope.3.semanticHash=45f0f69348cf0625
scope.4.id=function:runtime_context.set_current
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=40
scope.4.semanticHash=90b75b70366fa056
scope.5.id=function:runtime_context.current
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=44
scope.5.semanticHash=1136505bd37c301e
scope.6.id=function:_refresh_roles
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=52
scope.6.semanticHash=1a79e429e45f3ab2
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=50
scope.7.semanticHash=2bb770f53199a9dd
scope.8.id=function:runtime_context.install_globals
scope.8.kind=function
scope.8.startLine=54
scope.8.endLine=58
scope.8.semanticHash=88149fd82d191ce1
scope.9.id=function:_validate_lua_api_methods
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=75
scope.9.semanticHash=a2e9d7a7410f16bb
scope.10.id=function:runtime_context.install_environment
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=82
scope.10.semanticHash=5113abc151b478fc
scope.11.id=function:_ensure_runtime_helper_fields
scope.11.kind=function
scope.11.startLine=84
scope.11.endLine=94
scope.11.semanticHash=03deba20c49bbdd5
scope.12.id=function:runtime_context.install_runtime_helpers
scope.12.kind=function
scope.12.startLine=96
scope.12.endLine=108
scope.12.semanticHash=6b2c189b8feef4ee
scope.13.id=function:runtime_context.install_runtime_helper_globals
scope.13.kind=function
scope.13.startLine=110
scope.13.endLine=116
scope.13.semanticHash=b0bc83d38ac2bfe4
]]
