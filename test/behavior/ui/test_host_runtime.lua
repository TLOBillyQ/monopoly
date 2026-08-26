-- host_runtime.lua 直测：schedule 的 nil delay 缺省(转发时归一为 0)与逐名转发面。
-- 宿主无关(纯转发,端口经 runtime_ports.configure 注入)。
local lu = require("luaunit")

local host_runtime = require("src.ui.seams.host_runtime")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local support = require("test.support.shared_support")

TestHostRuntime = {}

function TestHostRuntime:setUp()
  runtime_ports.reset_for_tests()
end

function TestHostRuntime:tearDown()
  runtime_ports.reset_for_tests()
  -- 拆了共享端口基线必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

-- nil delay 缺省:delay or 0 是转发表的归一化点,必须把 nil 落成 0。
function TestHostRuntime:test_schedule_forwards_nil_delay_as_zero()
  local received = {}
  runtime_ports.configure({
    schedule = function(delay, fn)
      received.delay = delay
      received.fn = fn
      return 42
    end,
  })

  local marker = function() end
  local result = host_runtime.schedule(nil, marker)

  lu.assertEvalToTrue(received.delay == 0, "nil delay must be normalized to 0")
  lu.assertEvalToTrue(received.fn == marker, "the callback must pass through")
  lu.assertEvalToTrue(result == 42, "the port result must pass through")
end

function TestHostRuntime:test_schedule_keeps_an_explicit_delay()
  local received = {}
  runtime_ports.configure({
    schedule = function(delay)
      received.delay = delay
    end,
  })

  host_runtime.schedule(3.0, function() end)
  lu.assertEvalToTrue(received.delay == 3.0, "an explicit delay must pass through unchanged")
end

return TestHostRuntime
