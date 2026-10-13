require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- item_slot_denial.lua 数据契约 pin (#293 变异清扫)。
-- 既有 turn 测试对拒因文案/时长断言全部自引用
-- (intent.text == denial_cfg.text_for_reason(...))，文案与常量本身从没被
-- 硬编码钉过，mutate 的「常量 → nil / 字面量 → nil」位点全 survive。
-- 这里把文案、时长、拒因映射的字面子面值钉死。
local cfg = require("src.config.content.item_slot_denial")

describe("TestItemSlotDenialConfigPin", function()

  it("test_pins_denial_copy_and_duration", function()
    luassert.is.equal("现阶段该卡无法使用", cfg.PHASE_DENIED_TEXT)
    luassert.is.equal("你的现金不足，该卡当前无法使用", cfg.INSUFFICIENT_FUNDS_TEXT)
    luassert.is.equal("没有合适的目标，该卡当前无法使用", cfg.NO_TARGET_TEXT)
    luassert.is.equal("本回合已使用过同类效果的卡，该卡当前无法使用", cfg.EFFECT_GROUP_USED_TEXT)
    luassert.is.equal("该卡当前无法使用", cfg.GENERIC_DENIED_TEXT)
    luassert.is.equal(2.0, cfg.DURATION)
  end)

  it("test_pins_reason_to_copy_map", function()
    -- 用 assertEquals 而非 assertItemsEquals：后者只比值的多重集，放过键被
    -- 错位变异改名(如 offer_in_phases_not_allowed → offenilallowed)的情况。
    luassert.is.same({
      not_current_turn = "现阶段该卡无法使用",
      no_item_window = "现阶段该卡无法使用",
      offer_in_phases_not_allowed = "现阶段该卡无法使用",
      insufficient_funds = "你的现金不足，该卡当前无法使用",
      special_condition_failed = "没有合适的目标，该卡当前无法使用",
      effect_group_used = "本回合已使用过同类效果的卡，该卡当前无法使用",
    }, cfg.TEXT_BY_REASON)
  end)

  it("test_unknown_reason_falls_back_to_generic", function()
    luassert.is.equal(cfg.GENERIC_DENIED_TEXT, cfg.text_for_reason("totally_unknown_reason"))
  end)

  it("test_dedupe_key_joins_parts_with_colon_separator", function()
    -- #293:dedupe_key 的 ":" separator 变异(→ nil)未测;既有 turn 测试全部
    -- 自引用(两边同一函数),只有硬编码格式断言可分。
    local key = cfg.dedupe_key(7, 2001, "not_current_turn")
    luassert.truthy(key == "item_slot_denied:7:2001:not_current_turn", "dedupe key should join parts with colons; got " .. tostring(key))
  end)


end)
