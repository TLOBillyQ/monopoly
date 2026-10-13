require("test.bootstrap").install_package_paths()
-- 道具时机 fuzz（规则 + 调度层）分片 1/2。驱动器与设计注释见
-- test/support/fuzz/item_timing.lua（#190 分片让 LPT 并行吸收，总 seed 数不变）。
local fuzz = require("test.support.fuzz.item_timing")



describe("TestItemTimingFuzz", function()
  before_each(function()
    fuzz.reset()
  end)
  it("test_every_timing_with_offerable_cards_must_ask_and_turns_must_not_stall", function()
    fuzz.run_range(fuzz.shard_range(1, 2))
  end)


end)
