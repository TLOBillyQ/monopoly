-- 道具时机 fuzz（规则 + 调度层）分片 2/2。驱动器与设计注释见
-- test/support/fuzz/item_timing.lua（#190 分片让 LPT 并行吸收，总 seed 数不变）。
local fuzz = require("test.support.fuzz.item_timing")

TestItemTimingFuzzB = {}

function TestItemTimingFuzzB:setUp()
  fuzz.reset()
end

function TestItemTimingFuzzB:test_every_timing_with_offerable_cards_must_ask_and_turns_must_not_stall()
  fuzz.run_range(fuzz.shard_range(2, 2))
end


return TestItemTimingFuzzB
