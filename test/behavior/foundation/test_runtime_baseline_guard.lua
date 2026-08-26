local lu = require("luaunit")
local guard = require("test.support.runtime_baseline_guard")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local share_panel_port = require("src.foundation.ports.share_panel")

-- 原生 LuaUnit 迁移:单 describe 带 after_each → 拍平为一个 Test* 类(after_each →
-- tearDown);#463 纳入 share_panel port 后新增 1 例(现 7 例)。

TestRuntimeBaselineGuard = {}

function TestRuntimeBaselineGuard:tearDown()
  -- 本 spec 故意拆基线来演练守卫;跑完必须装回,否则车道守卫会把本 spec 自己记成泄漏。
  guard.restore()
end

function TestRuntimeBaselineGuard:test_reports_nothing_when_the_shared_baseline_is_intact()
  lu.assertEvalToTrue(#guard.missing_ports() == 0, "baseline should be intact between cases")
  lu.assertEvalToTrue(#guard.check_and_restore() == 0, "check_and_restore should report no leak")
end

function TestRuntimeBaselineGuard:test_detects_and_repairs_a_torn_down_runtime_ports()
  runtime_ports.reset_for_tests()

  local missing = guard.check_and_restore()

  lu.assertEvalToTrue(#missing == 1 and missing[1] == "runtime_ports", "should name runtime_ports as the leak")
  lu.assertEvalToTrue(runtime_ports.is_configured(), "check_and_restore should reinstall the baseline")
  lu.assertEvalToTrue(#guard.missing_ports() == 0, "baseline should be intact after repair")
end

function TestRuntimeBaselineGuard:test_detects_and_repairs_a_torn_down_paid_purchase_gateway()
  paid_purchase_port.reset_for_tests()

  local missing = guard.check_and_restore()

  lu.assertEvalToTrue(#missing == 1 and missing[1] == "paid_purchase_port", "should name paid_purchase_port as the leak")
  lu.assertEvalToTrue(paid_purchase_port.is_configured(), "check_and_restore should reinstall the baseline")
end

function TestRuntimeBaselineGuard:test_detects_both_ports_torn_down_at_once()
  runtime_ports.reset_for_tests()
  paid_purchase_port.reset_for_tests()

  local missing = guard.check_and_restore()

  lu.assertEvalToTrue(#missing == 2, "should name both leaked ports")
  lu.assertEvalToTrue(runtime_ports.is_configured(), "runtime_ports baseline should be reinstalled")
  lu.assertEvalToTrue(paid_purchase_port.is_configured(), "paid gateway baseline should be reinstalled")
end

function TestRuntimeBaselineGuard:test_detects_and_repairs_a_torn_down_share_panel_port()
  share_panel_port.reset_for_tests()

  local missing = guard.check_and_restore()

  lu.assertEvalToTrue(#missing == 1 and missing[1] == "share_panel_port", "should name share_panel_port as the leak")
  lu.assertEvalToTrue(share_panel_port.is_configured(), "check_and_restore should reinstall the baseline")
end

function TestRuntimeBaselineGuard:test_detects_and_repairs_a_cleared_tips_presenter()
  require("src.foundation.tips").configure_runtime({ clear_presenter = true })

  local missing = guard.check_and_restore()

  lu.assertEvalToTrue(#missing == 1 and missing[1] == "tips_presenter", "should name tips_presenter as the leak")
  lu.assertEvalToTrue(type(require("src.foundation.tips").runtime.presenter) == "function",
    "check_and_restore should reinstall the tips presenter")
end

function TestRuntimeBaselineGuard:test_assert_baseline_passes_when_intact_and_raises_naming_the_port_when_leaked()
  guard.assert_baseline()

  runtime_ports.reset_for_tests()
  local ok, err = pcall(guard.assert_baseline)
  lu.assertEvalToTrue(not ok, "assert_baseline should raise on a leaked baseline")
  lu.assertEvalToTrue(tostring(err):find("runtime_ports", 1, true) ~= nil, "error should name the leaked port")
  lu.assertEvalToTrue(runtime_ports.is_configured(), "assert_baseline should still reinstall the baseline")
end


return TestRuntimeBaselineGuard
