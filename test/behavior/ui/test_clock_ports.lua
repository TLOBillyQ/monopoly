-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- src.ui.ports.clock 包装面直测：build() 的四个时间函数逐名转发 foundation
-- runtime_ports。未装配时透传 runtime_ports 默认值(全 0)；configure 后逐名委托
-- 宿主实现。——行为车道没有直接驱动过这个包装面，clock 的 wall_*/cpu_* 语义
-- 只被 gameplay_loop_ports 的独立 clock 组覆盖（#293 清 clock.lua 幸存者的测错
-- 维度缺口：补真正驱动本包装面的测试）。
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local clock_ports = require("src.ui.ports.clock")

describe("TestClockPorts", function()

before_each(function()
  runtime_ports.reset_for_tests()
end)

after_each(function()
  support.restore_runtime_services()
end)

it("test_build_returns_the_four_clock_functions", function()
  local ports = clock_ports.build()
  luassert.is.equal( "function",type(ports.wall_now_seconds))
  luassert.is.equal( "function",type(ports.wall_diff_seconds))
  luassert.is.equal( "function",type(ports.cpu_now_seconds))
  luassert.is.equal( "function",type(ports.cpu_diff_seconds))
end)

it("test_unconfigured_runtime_ports_degrade_to_zero_defaults", function()
  local ports = clock_ports.build()
  luassert.is.equal( 0,ports.wall_now_seconds(), "wall_now_seconds default is 0")
  luassert.is.equal( 0,ports.wall_diff_seconds(1.0, 2.0), "wall_diff_seconds default is 0")
  luassert.is.equal( 0,ports.cpu_now_seconds(), "cpu_now_seconds default is 0")
  luassert.is.equal( 0,ports.cpu_diff_seconds(1.0, 2.0), "cpu_diff_seconds default is 0")
end)

it("test_build_delegates_to_configured_runtime_ports_per_name", function()
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
  luassert.is.equal( 42.0,ports.wall_now_seconds(), "wall_now_seconds should forward to configured impl")
  luassert.is.equal( 2.0,ports.wall_diff_seconds(9.0, 7.0), "wall_diff should forward diff semantics")
  luassert.is.equal( 1.5,ports.cpu_now_seconds(), "cpu_now_seconds should forward to configured impl")
  luassert.is.equal( 2.0,ports.cpu_diff_seconds(9.0, 7.0), "cpu_diff should forward diff semantics")
end)

end)
