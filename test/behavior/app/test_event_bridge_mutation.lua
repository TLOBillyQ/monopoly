-- Mutation-pinning spec for src/app/event_bridge.lua.
-- Drives M.install with a fake LuaAPI so we can capture a registered event
-- callback, invoke it, and observe that state.game is set from get_current_game.
--
-- 原生 LuaUnit 改写:无钩子 describe → 文件级 TestEventBridgeMutation 单类
-- (不拆类),语句位裸 assert → lu.assertEvalToTrue。用例数与改写前一一对应(1 例)。

local lu = require("luaunit")
local runtime_context = require("src.host.context")
local visual_hold = require("src.ui.visual_hold")
local event_bridge = require("src.app.event_bridge")

TestEventBridgeMutation = {}

local function build_event_host()
  local active_callbacks = {}
  local triggers_by_name = {}
  local unregistered = {}

  local lua_api = {
    global_register_custom_event = function(name, callback)
      local trigger = { event_name = name }
      active_callbacks[trigger] = callback
      triggers_by_name[name] = trigger
      return trigger
    end,
    global_unregister_custom_event = function(trigger)
      unregistered[#unregistered + 1] = trigger
      active_callbacks[trigger] = nil
    end,
  }

  return lua_api, active_callbacks, triggers_by_name, unregistered
end

function TestEventBridgeMutation:tearDown()
  if event_bridge.uninstall then
    event_bridge.uninstall()
  end
end

function TestEventBridgeMutation:test_uninstall_removes_both_registered_event_callbacks()
  local lua_api, active_callbacks, triggers_by_name = build_event_host()
  local saved_ctx = runtime_context.current()
  runtime_context.set_current({ env = { LuaAPI = lua_api } })

  event_bridge.install({}, function() return {} end)
  event_bridge.uninstall()

  runtime_context.set_current(saved_ctx)

  local events = require("src.foundation.events")
  lu.assertNil(active_callbacks[triggers_by_name[events.land.tile_upgraded]])
  lu.assertNil(active_callbacks[triggers_by_name[events.intent.need_choice]])
end

function TestEventBridgeMutation:test_uninstall_is_idempotent()
  local lua_api, _, _, unregistered = build_event_host()
  local saved_ctx = runtime_context.current()
  runtime_context.set_current({ env = { LuaAPI = lua_api } })

  event_bridge.install({}, function() return {} end)
  event_bridge.uninstall()
  event_bridge.uninstall()

  runtime_context.set_current(saved_ctx)

  lu.assertEquals(#unregistered, 2)
end

function TestEventBridgeMutation:test_repeated_install_does_not_register_duplicate_events()
  local register_count = 0
  local lua_api = {
    global_register_custom_event = function(_, callback)
      register_count = register_count + 1
      return { callback = callback }
    end,
    global_unregister_custom_event = function() end,
  }
  local saved_ctx = runtime_context.current()
  runtime_context.set_current({ env = { LuaAPI = lua_api } })

  event_bridge.install({}, function() return {} end)
  event_bridge.install({}, function() return {} end)

  runtime_context.set_current(saved_ctx)

  lu.assertEquals(register_count, 2)
end

function TestEventBridgeMutation:test_stores_the_get_current_game_result_on_state_game_when_an_event_fires_L16_nil()
  local registered = {}
  local fake_ctx = {
    env = {
      LuaAPI = {
        global_register_custom_event = function(name, callback)
          registered[name] = callback
        end,
      },
    },
  }
  local saved_ctx = runtime_context.current()
  runtime_context.set_current(fake_ctx)

  -- state.game is assigned before run_or_defer runs, so a no-op stub is enough
  -- to isolate the L16 assignment without invoking downstream handlers.
  local saved_run_or_defer = visual_hold.run_or_defer
  visual_hold.run_or_defer = function() end

  local sentinel_game = { marker = "the_current_game" }
  local state = {}
  event_bridge.install(state, function() return sentinel_game end)

  -- Invoke the first registered callback with the host's (self, _, data) shape.
  local _, callback = next(registered)
  local fired = callback ~= nil
  if callback then
    callback(nil, nil, { payload = true })
  end

  visual_hold.run_or_defer = saved_run_or_defer
  runtime_context.set_current(saved_ctx)

  lu.assertEvalToTrue(fired, "at least one event must have been registered to invoke")
  -- L16 `get_current_game()` -> nil would leave state.game = nil.
  lu.assertEvalToTrue(state.game == sentinel_game,
    "state.game must be the get_current_game() result; got " .. tostring(state.game))
end

-- #293 复核:install 的 3 处守卫断言 + run_or_defer 的 source 标签未测,4 个
-- survivor 全属此族;补钉后逐条击杀。

function TestEventBridgeMutation:test_install_asserts_missing_state_L9_nil()
  lu.assertErrorMsgContains("missing state", function()
    event_bridge.install(nil, function() end)
  end)
end

function TestEventBridgeMutation:test_install_asserts_missing_get_current_game_L10_nil()
  lu.assertErrorMsgContains("missing get_current_game", function()
    event_bridge.install({}, nil)
  end)
end

function TestEventBridgeMutation:test_install_asserts_when_event_registration_fails_L26_nil()
  -- host.register_custom_event 在 LuaAPI 缺函数时返回 false(函数存在则恒
  -- 返回 true,真实调用结果在第二返回值)——空 LuaAPI 才触发 event_bridge
  -- 的断言。
  local fake_ctx = {
    env = {
      LuaAPI = {},
    },
  }
  local saved_ctx = runtime_context.current()
  runtime_context.set_current(fake_ctx)
  local ok, err = pcall(function()
    event_bridge.install({}, function() end)
  end)
  runtime_context.set_current(saved_ctx)
  lu.assertEvalToTrue(ok == false, "failed registration should assert")
  lu.assertEvalToTrue(tostring(err):find("global_register_custom_event", 1, true) ~= nil,
    "assert should name the missing LuaAPI function: " .. tostring(err))
end

function TestEventBridgeMutation:test_run_or_defer_carries_the_runtime_event_source_L15_nil()
  local registered = {}
  local fake_ctx = {
    env = {
      LuaAPI = {
        global_register_custom_event = function(name, callback)
          registered[name] = callback
        end,
      },
    },
  }
  local saved_ctx = runtime_context.current()
  runtime_context.set_current(fake_ctx)

  local seen_source = nil
  local saved_run_or_defer = visual_hold.run_or_defer
  visual_hold.run_or_defer = function(_, _, source) seen_source = source end

  local state = {}
  event_bridge.install(state, function() return {} end)
  local _, callback = next(registered)
  local fired = callback ~= nil
  if callback then
    callback(nil, nil, { payload = true })
  end

  visual_hold.run_or_defer = saved_run_or_defer
  runtime_context.set_current(saved_ctx)

  lu.assertEvalToTrue(fired, "at least one event must have been registered to invoke")
  -- L15 `"runtime_event"` -> nil would leave the source label nil.
  lu.assertEvalToTrue(seen_source == "runtime_event",
    "run_or_defer must carry the runtime_event source; got " .. tostring(seen_source))
end


return TestEventBridgeMutation
