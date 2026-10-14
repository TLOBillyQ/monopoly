-- 道具时机 fuzz（loop 层生产帧路径）分片 1/3。驱动器与设计注释见
-- test/support/fuzz/item_timing_loop.lua（#190 分片让 LPT 并行吸收，总 seed 数不变）。
local fuzz = require("test.support.fuzz.item_timing_loop")

describe("TestItemTimingLoopFuzz", function()
  before_each(function()
    fuzz.reset()
  end)

  it("test_every_timing_asks_gates_never_livelock_turns_advance", function()
    fuzz.run_range(fuzz.shard_range(1, 3))
  end)
end)
