-- 道具时机 fuzz（loop 层生产帧路径）分片 2/3。驱动器与设计注释见
-- test/support/fuzz/item_timing_loop.lua（#190 分片让 LPT 并行吸收，总 seed 数不变）。
local fuzz = require("test.support.fuzz.item_timing_loop")

TestItemTimingLoopFuzzB = {}

function TestItemTimingLoopFuzzB:setUp()
  fuzz.reset()
end

function TestItemTimingLoopFuzzB:test_every_timing_asks_gates_never_livelock_turns_advance()
  fuzz.run_range(fuzz.shard_range(2, 3))
end


return TestItemTimingLoopFuzzB
