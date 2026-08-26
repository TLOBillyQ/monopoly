-- transaction_context 的错误/校验路径:适配器 pcall 失败告警与非法参数断言。
-- #293 复核:这 9 个 survivor 同属一个缺口族——回调错误路径与校验断言未测,
-- 补本文件后逐条击杀(equip/unequip/applier 错误告警 + 4 处非法参数断言)。
local lu = require("luaunit")

local log_capture = require("test.support.log_capture")
local context = require("src.app.cosmetics.transaction_context")

TestTransactionContext = {}

function TestTransactionContext:setUp()
  context.reset_for_tests()
end

function TestTransactionContext:test_unequip_adapter_error_logs_warn_with_error_text()
  context.configure_unequip(function() error("unequip boom") end)
  local ok, _, captured = log_capture.capture(function()
    context.call_unequip_adapter("p1")
  end)
  lu.assertEvalToTrue(ok == true, "adapter error should be swallowed")
  local joined = table.concat(captured.lines, "\n")
  lu.assertEvalToTrue(joined:find("unequip callback failed", 1, true) ~= nil,
    "warn should name the failing unequip callback: " .. joined)
  lu.assertEvalToTrue(joined:find("unequip boom", 1, true) ~= nil,
    "warn should carry the adapter error text: " .. joined)
end

function TestTransactionContext:test_equip_adapter_error_returns_false_without_warn()
  context.configure_equip(function() error("equip boom") end)
  local ok, _, captured = log_capture.capture(function()
    lu.assertEvalToTrue(context.call_equip_adapter("p1", {}) == false,
      "failed equip should return false")
  end)
  lu.assertEvalToTrue(ok == true, "adapter error should be swallowed")
  lu.assertEvalToTrue(#captured.lines == 0,
    "failed equip should not log a warn: " .. table.concat(captured.lines, ";"))
end

function TestTransactionContext:test_configure_equip_rejects_non_function()
  lu.assertErrorMsgContains("invalid skin equip callback", function()
    context.configure_equip("not_a_function")
  end)
end

function TestTransactionContext:test_configure_unequip_rejects_non_function()
  lu.assertErrorMsgContains("invalid skin unequip callback", function()
    context.configure_unequip({})
  end)
end

function TestTransactionContext:test_configure_transaction_result_applier_rejects_non_function()
  lu.assertErrorMsgContains("invalid skin transaction result applier", function()
    context.configure_transaction_result_applier(42)
  end)
end

function TestTransactionContext:test_result_applier_error_logs_warn_with_error_text()
  context.configure_transaction_result_applier(function() error("applier boom") end)
  local ok, _, captured = log_capture.capture(function()
    context.call_transaction_result_applier({}, {})
  end)
  lu.assertEvalToTrue(ok == true, "applier error should be swallowed")
  local joined = table.concat(captured.lines, "\n")
  lu.assertEvalToTrue(joined:find("transaction result applier failed", 1, true) ~= nil,
    "warn should name the failing applier: " .. joined)
  lu.assertEvalToTrue(joined:find("applier boom", 1, true) ~= nil,
    "warn should carry the applier error text: " .. joined)
end

function TestTransactionContext:test_configure_archive_rejects_non_table()
  lu.assertErrorMsgContains("invalid skin archive", function()
    context.configure_archive("not_a_table")
  end)
end

function TestTransactionContext:test_archive_call_swallows_adapter_error()
  context.configure_archive({
    read = function() error("archive boom") end,
  })
  lu.assertNil(context.archive_call("read", "p1", 5005),
    "failed archive call should return nil")
end

return TestTransactionContext
