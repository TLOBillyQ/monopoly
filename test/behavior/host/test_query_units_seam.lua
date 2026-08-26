-- Behavior specs for the host_runtime.query_units / query_unit seam added in Issue #84.
-- These wrappers isolate src/ui/render/board/scene.lua from direct LuaAPI calls.

local lu = require("luaunit")
local host_runtime = require("src.host.init")
local runtime_context = require("src.host.context")

local function _with_current(ctx, fn)
  local saved = runtime_context.current()
  runtime_context.set_current(ctx)
  local ok, res = pcall(fn)
  runtime_context.set_current(saved)
  if not ok then error(res, 0) end
  return res
end

TestQueryUnitsSeam = {}

function TestQueryUnitsSeam:test_forwards_names_to_luaapi_query_units_and_returns_the_result()
  local captured = {}
  local ctx = {
    env = {
      LuaAPI = {
        query_units = function(names)
          captured.names = names
          return { { name = "u1" }, { name = "u2" } }
        end,
      },
    },
  }
  local result = _with_current(ctx, function()
    return host_runtime.query_units({ "a", "b" })
  end)
  lu.assertEvalToTrue(type(result) == "table", "query_units should return a table")
  lu.assertEvalToTrue(result[1].name == "u1", "query_units should return first unit")
  lu.assertEvalToTrue(result[2].name == "u2", "query_units should return second unit")
  lu.assertEvalToTrue(captured.names[1] == "a", "query_units should forward names")
  lu.assertEvalToTrue(captured.names[2] == "b", "query_units should forward names")
end

function TestQueryUnitsSeam:test_returns_nil_when_luaapi_query_units_is_missing()
  local result = _with_current({ env = { LuaAPI = {} } }, function()
    return host_runtime.query_units({ "a" })
  end)
  lu.assertEvalToTrue(result == nil, "query_units should return nil when host API is missing")
end

function TestQueryUnitsSeam:test_returns_nil_when_no_runtime_context_is_installed()
  local result = _with_current(nil, function()
    return host_runtime.query_units({ "a" })
  end)
  lu.assertEvalToTrue(result == nil, "query_units should return nil without a runtime context")
end

function TestQueryUnitsSeam:test_forwards_name_to_luaapi_query_unit_and_returns_the_result()
  local captured = {}
  local ctx = {
    env = {
      LuaAPI = {
        query_unit = function(name)
          captured.name = name
          return { name = "ground" }
        end,
      },
    },
  }
  local result = _with_current(ctx, function()
    return host_runtime.query_unit("ground")
  end)
  lu.assertEvalToTrue(type(result) == "table", "query_unit should return a unit")
  lu.assertEvalToTrue(result.name == "ground", "query_unit should return the queried unit")
  lu.assertEvalToTrue(captured.name == "ground", "query_unit should forward the name")
end

function TestQueryUnitsSeam:test_returns_nil_when_luaapi_query_unit_is_missing()
  local result = _with_current({ env = { LuaAPI = {} } }, function()
    return host_runtime.query_unit("ground")
  end)
  lu.assertEvalToTrue(result == nil, "query_unit should return nil when host API is missing")
end

function TestQueryUnitsSeam:test_returns_nil_when_no_runtime_context_is_installed_2()
  local result = _with_current(nil, function()
    return host_runtime.query_unit("ground")
  end)
  lu.assertEvalToTrue(result == nil, "query_unit should return nil without a runtime context")
end

function TestQueryUnitsSeam:test_forwards_trigger_to_luaapi_global_unregister_custom_event()
  local captured = {}
  local ctx = {
    env = {
      LuaAPI = {
        global_unregister_custom_event = function(trigger)
          captured.trigger = trigger
        end,
      },
    },
  }
  local result = _with_current(ctx, function()
    return host_runtime.unregister_custom_event(42)
  end)
  lu.assertEvalToTrue(result == true, "unregister_custom_event should return true on success")
  lu.assertEvalToTrue(captured.trigger == 42, "unregister_custom_event should forward trigger")
end

function TestQueryUnitsSeam:test_returns_false_when_trigger_is_nil()
  local result = _with_current({ env = { LuaAPI = {} } }, function()
    return host_runtime.unregister_custom_event(nil)
  end)
  lu.assertEvalToTrue(result == false, "unregister_custom_event should reject nil trigger")
end

function TestQueryUnitsSeam:test_returns_false_when_luaapi_global_unregister_custom_event_is_missing()
  local result = _with_current({ env = { LuaAPI = {} } }, function()
    return host_runtime.unregister_custom_event(42)
  end)
  lu.assertEvalToTrue(result == false, "unregister_custom_event should return false when host API is missing")
end


return TestQueryUnitsSeam
