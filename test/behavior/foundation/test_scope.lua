local lu = require("luaunit")
local logger = require("src.foundation.log")
local scope = require("src.foundation.scope")

TestScope = {}

function TestScope:test_runs_cleanup_in_lifo_order_and_ignores_return_values()
  local order = {}
  local resource_scope = scope.new()

  resource_scope:defer(function()
    order[#order + 1] = "first"
    return "not an error"
  end)
  resource_scope:defer(function()
    order[#order + 1] = "second"
  end)

  resource_scope:destroy()

  lu.assertEquals(order, { "second", "first" })
end

function TestScope:test_invokes_cleanup_without_arguments()
  local argument_count = nil
  local resource_scope = scope.new()
  resource_scope:defer(function(...)
    argument_count = select("#", ...)
  end)

  resource_scope:destroy()

  lu.assertEquals(argument_count, 0)
end

function TestScope:test_destroy_is_idempotent_and_reentrant()
  local calls = 0
  local resource_scope = scope.new()

  resource_scope:defer(function()
    calls = calls + 1
    resource_scope:destroy()
  end)

  resource_scope:destroy()
  resource_scope:destroy()

  lu.assertEquals(calls, 1)
end

function TestScope:test_fork_destroy_cascades_in_one_lifo_order()
  local order = {}
  local parent = scope.new()
  parent:defer(function()
    order[#order + 1] = "parent-first"
  end)
  local child = parent:fork()
  child:defer(function()
    order[#order + 1] = "child"
  end)
  parent:defer(function()
    order[#order + 1] = "parent-last"
  end)

  parent:destroy()

  lu.assertEquals(order, { "parent-last", "child", "parent-first" })
end

function TestScope:test_destroy_continues_after_cleanup_errors_and_raises_first_error()
  local calls = {}
  local warnings = {}
  local original_warn = logger.warn
  logger.warn = function(...)
    warnings[#warnings + 1] = table.concat({ ... }, " ")
  end

  local resource_scope = scope.new()
  resource_scope:defer(function()
    calls[#calls + 1] = "first"
    error("first cleanup error")
  end)
  resource_scope:defer(function()
    calls[#calls + 1] = "second"
    error("second cleanup error")
  end)

  local ok, err = pcall(function()
    resource_scope:destroy()
  end)
  logger.warn = original_warn

  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "second cleanup error")
  lu.assertEquals(calls, { "second", "first" })
  lu.assertEquals(#warnings, 1)
  lu.assertStrContains(warnings[1], "first cleanup error")
end

function TestScope:test_defer_on_destroyed_scope_runs_immediately()
  local calls = 0
  local resource_scope = scope.new()
  resource_scope:destroy()

  resource_scope:defer(function()
    calls = calls + 1
  end)

  lu.assertEquals(calls, 1)
end

function TestScope:test_defer_during_destruction_is_rejected()
  local resource_scope = scope.new()
  resource_scope:defer(function()
    lu.assertErrorMsgContains("destroying scope", function()
      resource_scope:defer(function() end)
    end)
  end)

  resource_scope:destroy()
end

function TestScope:test_scope_has_no_active_cleanup_after_destroy()
  local calls = 0
  local resource_scope = scope.new()
  resource_scope:defer(function()
    calls = calls + 1
  end)

  resource_scope:destroy()
  resource_scope:defer(function()
    calls = calls + 1
  end)
  resource_scope:destroy()

  lu.assertEquals(calls, 2)
end

function TestScope:test_cleanup_error_with_nil_value_still_fails_destroy()
  local resource_scope = scope.new()
  resource_scope:defer(function()
    error(nil)
  end)

  local ok = pcall(function()
    resource_scope:destroy()
  end)

  lu.assertFalse(ok)
end

return TestScope
