-- 道具时机 fuzz（loop 层生产帧路径）分片 3/3。驱动器与设计注释见
-- test/support/fuzz/item_timing_loop.lua（#190 分片让 LPT 并行吸收，总 seed 数不变）。
-- 原生 LuaUnit 改写：describe 拍平为 Test* 类，before_each → setUp。
local fuzz = require("test.support.fuzz.item_timing_loop")

TestItemTimingLoopFuzzC = {}

function TestItemTimingLoopFuzzC:setUp()
  fuzz.reset()
end

function TestItemTimingLoopFuzzC:test_every_timing_asks_gates_never_livelock_turns_advance()
  fuzz.run_range(fuzz.shard_range(3, 3))
end


return TestItemTimingLoopFuzzC
