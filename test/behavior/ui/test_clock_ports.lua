-- src.ui.ports.clock 包装面直测：build() 的四个时间函数逐名转发 foundation
-- runtime_ports。未装配时透传 runtime_ports 默认值(全 0)；configure 后逐名委托
-- 宿主实现。——行为车道没有直接驱动过这个包装面，clock 的 wall_*/cpu_* 语义
-- 只被 gameplay_loop_ports 的独立 clock 组覆盖（#293 清 clock.lua 幸存者的测错
-- 维度缺口：补真正驱动本包装面的测试）。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local clock_ports = require("src.ui.ports.clock")

TestClockPorts = {}

function TestClockPorts:setUp()
  runtime_ports.reset_for_tests()
end

function TestClockPorts:tearDown()
  support.restore_runtime_services()
end

function TestClockPorts:test_build_returns_the_four_clock_functions()
  local ports = clock_ports.build()
  lu.assertIs(type(ports.wall_now_seconds), "function")
  lu.assertIs(type(ports.wall_diff_seconds), "function")
  lu.assertIs(type(ports.cpu_now_seconds), "function")
  lu.assertIs(type(ports.cpu_diff_seconds), "function")
end

function TestClockPorts:test_unconfigured_runtime_ports_degrade_to_zero_defaults()
  local ports = clock_ports.build()
  lu.assertIs(ports.wall_now_seconds(), 0, "wall_now_seconds default is 0")
  lu.assertIs(ports.wall_diff_seconds(1.0, 2.0), 0, "wall_diff_seconds default is 0")
  lu.assertIs(ports.cpu_now_seconds(), 0, "cpu_now_seconds default is 0")
  lu.assertIs(ports.cpu_diff_seconds(1.0, 2.0), 0, "cpu_diff_seconds default is 0")
end

function TestClockPorts:test_build_delegates_to_configured_runtime_ports_per_name()
  runtime_ports.configure({
    wall_now_seconds = function()
      return 42.0
    end,
    wall_diff_seconds = function(a, b)
      return (a or 0) - (b or 0)
    end,
    cpu_now_seconds = function()
      return 1.5
    end,
    cpu_diff_seconds = function(a, b)
      return (a or 0) - (b or 0)
    end,
  })
  local ports = clock_ports.build()
  lu.assertIs(ports.wall_now_seconds(), 42.0, "wall_now_seconds should forward to configured impl")
  lu.assertIs(ports.wall_diff_seconds(9.0, 7.0), 2.0, "wall_diff should forward diff semantics")
  lu.assertIs(ports.cpu_now_seconds(), 1.5, "cpu_now_seconds should forward to configured impl")
  lu.assertIs(ports.cpu_diff_seconds(9.0, 7.0), 2.0, "cpu_diff should forward diff semantics")
end

return TestClockPorts