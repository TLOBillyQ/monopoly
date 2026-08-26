-- item_slots_highlight phase-advance 去重补测(#362 锚定语义,#596 收归 ui.state)。
-- 不再预置内部缓存字段:去重状态由前一次真实观察建立,断言只看宿主是否收到
-- 全局「重置高亮」。这样变异掉签名派生或 nil 判定都能被区分。
local support = require("test.support.shared_support")
local highlight = require("src.ui.coord.item_slots_highlight")
local events = require("src.ui.coord.item_slots_events")

local _assert_eq = support.assert_eq

-- 按顺序喂入若干快照,返回宿主收到的全局重置次数。
local function _emits_for(snapshots)
  local emit_count = 0
  support.with_patches({
    { target = events, key = "emit_global_reset_animation", value = function()
      emit_count = emit_count + 1
    end },
  }, function()
    local state = { game = { turn = {} } }
    for _, snapshot in ipairs(snapshots) do
      highlight.maybe_emit_phase_advance_reset(state, snapshot.slots)
    end
  end)
  return emit_count
end

TestItemSlotsHighlightGaps = {}

-- 同一集合连续观察只发一次:杀「签名派生 → nil」(签名恒 nil 时两次都与缓存
-- 不等,会误发第二次)。
function TestItemSlotsHighlightGaps:test_repeated_pickable_set_emits_once()
  _assert_eq(_emits_for({ { slots = { true, true } }, { slots = { true, true } } }), 1,
    "an unchanged pickable set must not re-emit the global reset")
end

-- 不同集合各发一次:杀「恒不变化」类变异(去重条件恒真时第二次会被吞掉)。
function TestItemSlotsHighlightGaps:test_changed_pickable_set_emits_again()
  _assert_eq(_emits_for({ { slots = { true, true } }, { slots = { true, false } } }), 2,
    "a changed pickable set must emit a fresh global reset")
end

-- 无快照与非空集合互不冒充:杀 nil 判定的 == → true 折叠(把真实集合也当成
-- 「缺失」而与前一次缺失去重,漏发第二次)。
function TestItemSlotsHighlightGaps:test_absent_snapshot_differs_from_a_real_set()
  _assert_eq(_emits_for({ { slots = nil }, { slots = { true } } }), 2,
    "a real pickable set must differ from an absent snapshot")
end

-- 无快照与空集合也是两个状态(而非同一个 "none" 哨兵)。
function TestItemSlotsHighlightGaps:test_absent_snapshot_differs_from_an_empty_set()
  _assert_eq(_emits_for({ { slots = nil }, { slots = {} } }), 2,
    "an empty set must differ from an absent snapshot")
end

return TestItemSlotsHighlightGaps
