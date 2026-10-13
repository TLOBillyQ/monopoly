-- foundation.scope 资源作用域直测:LIFO 清理、幂等 destroy、fork 级联、清理期报错。
--
-- 断言层迁移(#74 第一步「先断言、后结构」):断言后端从 LuaUnit 的 lu.* 换成真
-- luassert,结构、用例集合与期望值一字未改。断言对象经 test.support.luassert_loader
-- 从项目工具缓存局部取得,不接管全局 Lua assert——旧运行器与 LuaUnit 的后端语义
-- 仍挂在全局 assert 上,覆盖它等于换执行后端而不是换断言词汇。
--
-- 迁移口径(详见 CODING_STANDARDS.md 的「断言层迁移」):
--   - 参数顺序是 (expected, actual),与 LuaUnit 的 (actual, expected) 相反;
--   - 表比较用 is.same(深比较),is.equal 是 `==` 身份比较;
--   - 严格布尔用 is_true/is_false,truthiness 用 truthy/falsy;
--   - 子串口径走 matches(..., 1, true) 或 has_error.match(..., 1, true)。
require("test.bootstrap").install_package_paths()

local luassert = assert(require("test.support.luassert_loader").load())
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

  luassert.is.same({ "second", "first" }, order)
end

function TestScope:test_invokes_cleanup_without_arguments()
  local argument_count = nil
  local resource_scope = scope.new()
  resource_scope:defer(function(...)
    argument_count = select("#", ...)
  end)

  resource_scope:destroy()

  luassert.is.equal(0, argument_count)
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

  luassert.is.equal(1, calls)
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

  luassert.is.same({ "parent-last", "child", "parent-first" }, order)
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

  luassert.is_false(ok)
  luassert.matches("second cleanup error", tostring(err), 1, true)
  luassert.is.same({ "second", "first" }, calls)
  luassert.is.equal(1, #warnings)
  luassert.matches("first cleanup error", warnings[1], 1, true)
end

function TestScope:test_defer_on_destroyed_scope_runs_immediately()
  local calls = 0
  local resource_scope = scope.new()
  resource_scope:destroy()

  resource_scope:defer(function()
    calls = calls + 1
  end)

  luassert.is.equal(1, calls)
end

function TestScope:test_defer_during_destruction_is_rejected()
  local resource_scope = scope.new()
  resource_scope:defer(function()
    -- LuaUnit 的 assertErrorMsgContains 是子串口径 → has_error.match 的 plain 模式。
    luassert.has_error.match(function()
      resource_scope:defer(function() end)
    end, "destroying scope", 1, true)
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

  luassert.is.equal(2, calls)
end

function TestScope:test_cleanup_error_with_nil_value_still_fails_destroy()
  local resource_scope = scope.new()
  resource_scope:defer(function()
    error(nil)
  end)

  local ok = pcall(function()
    resource_scope:destroy()
  end)

  luassert.is_false(ok)
end

return TestScope
