require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local guard = require("test.support.runtime_baseline_guard")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local share_panel_port = require("src.foundation.ports.share_panel")


describe("TestRuntimeBaselineGuard", function()

  after_each(function()
    -- 本 spec 故意拆基线来演练守卫;跑完必须装回,否则车道守卫会把本 spec 自己记成泄漏。
    guard.restore()
  end)

  it("test_reports_nothing_when_the_shared_baseline_is_intact", function()
    luassert.truthy(#guard.missing_ports() == 0, "baseline should be intact between cases")
    luassert.truthy(#guard.check_and_restore() == 0, "check_and_restore should report no leak")
  end)

  it("test_detects_and_repairs_a_torn_down_runtime_ports", function()
    runtime_ports.reset_for_tests()

    local missing = guard.check_and_restore()

    luassert.truthy(#missing == 1 and missing[1] == "runtime_ports", "should name runtime_ports as the leak")
    luassert.truthy(runtime_ports.is_configured(), "check_and_restore should reinstall the baseline")
    luassert.truthy(#guard.missing_ports() == 0, "baseline should be intact after repair")
  end)

  it("test_detects_and_repairs_a_torn_down_paid_purchase_gateway", function()
    paid_purchase_port.reset_for_tests()

    local missing = guard.check_and_restore()

    luassert.truthy(#missing == 1 and missing[1] == "paid_purchase_port", "should name paid_purchase_port as the leak")
    luassert.truthy(paid_purchase_port.is_configured(), "check_and_restore should reinstall the baseline")
  end)

  it("test_detects_both_ports_torn_down_at_once", function()
    runtime_ports.reset_for_tests()
    paid_purchase_port.reset_for_tests()

    local missing = guard.check_and_restore()

    luassert.truthy(#missing == 2, "should name both leaked ports")
    luassert.truthy(runtime_ports.is_configured(), "runtime_ports baseline should be reinstalled")
    luassert.truthy(paid_purchase_port.is_configured(), "paid gateway baseline should be reinstalled")
  end)

  it("test_detects_and_repairs_a_torn_down_share_panel_port", function()
    share_panel_port.reset_for_tests()

    local missing = guard.check_and_restore()

    luassert.truthy(#missing == 1 and missing[1] == "share_panel_port", "should name share_panel_port as the leak")
    luassert.truthy(share_panel_port.is_configured(), "check_and_restore should reinstall the baseline")
  end)

  it("test_detects_and_repairs_a_cleared_tips_presenter", function()
    require("src.foundation.tips").configure_runtime({ clear_presenter = true })

    local missing = guard.check_and_restore()

    luassert.truthy(#missing == 1 and missing[1] == "tips_presenter", "should name tips_presenter as the leak")
    luassert.truthy(type(require("src.foundation.tips").runtime.presenter) == "function", "check_and_restore should reinstall the tips presenter")
  end)

  it("test_assert_baseline_passes_when_intact_and_raises_naming_the_port_when_leaked", function()
    guard.assert_baseline()

    runtime_ports.reset_for_tests()
    local ok, err = pcall(guard.assert_baseline)
    luassert.truthy(not ok, "assert_baseline should raise on a leaked baseline")
    luassert.truthy(tostring(err):find("runtime_ports", 1, true) ~= nil, "error should name the leaked port")
    luassert.truthy(runtime_ports.is_configured(), "assert_baseline should still reinstall the baseline")
  end)


end)
