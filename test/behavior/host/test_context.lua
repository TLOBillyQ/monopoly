-- host/context 变异 survivor 闭合(#261):守卫消息精确化、
-- `_resolve_game_api_roles` 的 `not ok or type() ~= "table"` or->and
-- (pcall 抛 table 错误对象时变异体会把错误对象当 roles 返回)、
-- install_globals 有效路径(杀 ~= -> ==)、globals 安装字面值、
-- synthetic_actor_registry 懒建(not 移除 / call->nil)。
local lu = require("luaunit")
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local runtime_context = require("src.host.context")

local _assert_eq = support.assert_eq

local function _lua_api()
  return {
    call_delay_time = function() end,
    global_register_custom_event = function() end,
    global_register_trigger_event = function() end,
    global_unregister_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = function() end,
  }
end

TestContext = {}

function TestContext:test_install_runtime_helpers_rejects_a_context_without_env()
  -- kills _refresh_roles' `ctx ~= nil and ctx.env ~= nil` `and` -> `or`
  -- (mutant passes the guard and silently swallows the missing env)
  -- and its "missing runtime context" -> nil.
  luax.has_error(function()
    runtime_context.install_runtime_helpers({})
  end, "missing runtime context")
end

function TestContext:test_install_runtime_helpers_rejects_a_nil_context()
  -- kills install_runtime_helpers' own "missing runtime context" -> nil.
  luax.has_error(function()
    runtime_context.install_runtime_helpers(nil)
  end, "missing runtime context")
end

function TestContext:test_install_environment_rejects_a_nil_context()
  -- kills install_environment's `and` -> `or` (mutant indexes nil and raises
  -- a different error) and "missing runtime context" -> nil.
  luax.has_error(function()
    runtime_context.install_environment(nil)
  end, "missing runtime context")
end

function TestContext:test_install_environment_rejects_env_without_luaapi()
  -- kills _validate_lua_api_methods' "missing LuaAPI" -> nil.
  luax.has_error(function()
    runtime_context.install_environment({ env = {} })
  end, "missing LuaAPI")
end

function TestContext:test_install_environment_returns_env_for_a_valid_context()
  local env = { LuaAPI = _lua_api() }
  _assert_eq(runtime_context.install_environment({ env = env }), env,
    "a valid context returns its env")
end

function TestContext:test_install_environment_requires_trigger_unregistration()
  local lua_api = _lua_api()
  lua_api.global_unregister_trigger_event = nil
  luax.has_error(function()
    runtime_context.install_environment({ env = { LuaAPI = lua_api } })
  end, "missing LuaAPI.global_unregister_trigger_event")
end

function TestContext:test_install_globals_rejects_a_nil_context()
  -- kills install_globals' `and` -> `or` and "missing runtime context" -> nil.
  luax.has_error(function()
    runtime_context.install_globals(nil)
  end, "missing runtime context")
end

function TestContext:test_install_runtime_helper_globals_rejects_nil_helpers()
  -- kills install_runtime_helper_globals' "missing helpers" -> nil.
  luax.has_error(function()
    runtime_context.install_runtime_helper_globals(nil)
  end, "missing helpers")
end

function TestContext:test_a_table_error_object_from_get_all_valid_roles_still_yields_empty_roles()
  -- kills _resolve_game_api_roles' `not ok or type(valid_roles) ~= "table"`
  -- `or` -> `and`: a pcall failure carrying a TABLE error object passes the
  -- mutant's type check and would be returned as if it were roles.
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        error({ code = 1 })
      end,
    },
  })
  local helpers = runtime_context.install_runtime_helpers(ctx)
  _assert_eq(type(helpers.roles), "table", "roles fall back to an empty table")
  _assert_eq(#helpers.roles, 0, "roles must be empty after a failed fetch")
  _assert_eq(helpers.roles.code, nil, "the error object must not leak into roles")
end

function TestContext:test_installs_helpers_refreshes_roles_and_publishes_globals()
  -- kills install_globals' `~=` -> `==` pair (valid ctx must pass the guard),
  -- the `{ install_globals = true }` true -> false (globals must appear),
  -- and _ensure_runtime_helper_fields' `not` removal / registry call -> nil.
  local saved_camera, saved_roles, saved_all = _G.camera_helper, _G.all_roles, _G.ALLROLES
  local ctx = runtime_context.new({
    LuaAPI = _lua_api(),
    GameAPI = { get_all_valid_roles = function() return { "r1" } end },
  })
  local seen_camera, seen_roles
  local ok, err = pcall(function()
    runtime_context.install_globals(ctx)
    -- 在恢复前捕获:{ install_globals = true } 的 true -> false 变异体
    -- 会跳过全局发布,两个全局都留不住。
    seen_camera, seen_roles = _G.camera_helper, _G.all_roles
  end)
  _G.camera_helper, _G.all_roles, _G.ALLROLES = saved_camera, saved_roles, saved_all
  lu.assertEvalToTrue(ok, "install_globals must succeed for a valid context: " .. tostring(err))
  lu.assertEvalToTrue(seen_camera ~= nil, "install_globals must publish the camera_helper global")
  lu.assertEvalToTrue(seen_roles ~= nil and seen_roles[1] == "r1", "install_globals must publish the roles global")
  lu.assertEvalToTrue(ctx.camera_helper ~= nil, "camera_helper is lazily built")
  lu.assertEvalToTrue(ctx.synthetic_actor_registry ~= nil, "synthetic_actor_registry is lazily built")
  _assert_eq(ctx.roles[1], "r1", "roles are refreshed from GameAPI")
end


return TestContext
