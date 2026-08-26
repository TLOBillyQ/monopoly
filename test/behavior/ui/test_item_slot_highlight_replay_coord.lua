-- 高亮重放计划 → 宿主动画的投递直测(#594):reset 只发一次全局重置,
-- replay 先全局重置再按槽位编号升序清除与高亮,发送失败留诊断不回滚记忆。
local support = require("test.support.shared_support")
local coord = require("src.ui.coord.item_slot_highlight_replay_coord")
local replay = require("src.ui.state.item_slot_highlight_replay")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local ui_events = require("src.ui.coord.ui_events")
local logger = require("src.foundation.log")

local _assert_eq = support.assert_eq

-- 在真实 events 之上捕获事件名序列:只换宿主出口(ui_events / client role),
-- 顺序与「重置高亮」次数都由被测链路真实产生。
local function _capture(fn, opts)
  opts = opts or {}
  local captured = { names = {}, targets = {}, warns = {}, attempts = 0 }
  support.with_patches({
    { target = runtime_ui, key = "get_client_role", value = function()
      return opts.role
    end },
    { target = ui_events, key = "send_to_role", value = function(role, name)
      captured.attempts = captured.attempts + 1
      if opts.fail then error("host exploded") end
      captured.names[#captured.names + 1] = name
      captured.targets[#captured.targets + 1] = role and role.id or "角色未知"
    end },
    { target = ui_events, key = "send_to_all", value = function(name)
      captured.attempts = captured.attempts + 1
      if opts.fail then error("host exploded") end
      captured.names[#captured.names + 1] = name
      captured.targets[#captured.targets + 1] = "全体"
    end },
    { target = logger, key = "warn", value = function(...)
      captured.warns[#captured.warns + 1] = table.concat({ ... }, " ")
    end },
  }, function() fn(captured) end)
  return captured
end

TestItemSlotHighlightReplayCoord = {}

-- reset 计划:只发一次全局重置,不发任何逐槽事件。
function TestItemSlotHighlightReplayCoord:test_reset_plan_emits_one_global_reset()
  local captured = _capture(function()
    coord.deliver(replay.PLAN_RESET, { false, false, false, false, false })
  end, { role = { id = 1 } })
  _assert_eq(#captured.names, 1, "reset 只发一次事件")
  _assert_eq(captured.names[1], "重置高亮", "reset 发全局重置")
end

-- replay 计划:全局重置 → 不可选槽升序清除 → 可选槽升序高亮。
function TestItemSlotHighlightReplayCoord:test_replay_plan_emits_reset_then_ordered_slots()
  local cases = {
    { snapshot = { true, false, true, false, false },
      expected = { "重置高亮", "重置高亮道具槽位牌2", "重置高亮道具槽位牌4",
        "重置高亮道具槽位牌5", "高亮道具槽位牌1", "高亮道具槽位牌3" } },
    { snapshot = { false, true, false, false, true },
      expected = { "重置高亮", "重置高亮道具槽位牌1", "重置高亮道具槽位牌3",
        "重置高亮道具槽位牌4", "高亮道具槽位牌2", "高亮道具槽位牌5" } },
    { snapshot = { true, true, true, true, true },
      expected = { "重置高亮", "高亮道具槽位牌1", "高亮道具槽位牌2",
        "高亮道具槽位牌3", "高亮道具槽位牌4", "高亮道具槽位牌5" } },
  }
  for _, case in ipairs(cases) do
    local captured = _capture(function()
      _assert_eq(coord.deliver(replay.PLAN_REPLAY, case.snapshot), true,
        "投递成功返回 true")
    end, { role = { id = 1 } })
    _assert_eq(table.concat(captured.names, ", "), table.concat(case.expected, ", "),
      "replay 的宿主事件顺序")
  end
end

-- none 计划不碰宿主。
function TestItemSlotHighlightReplayCoord:test_none_plan_emits_nothing()
  local captured = _capture(function()
    _assert_eq(coord.deliver(replay.PLAN_NONE, { true, false, true, false, false }),
      true, "none 计划视为完整送达")
  end, { role = { id = 1 } })
  _assert_eq(#captured.names, 0, "none 计划不发任何宿主事件")
end

-- 有本机角色按角色投递,缺省时广播全体。
function TestItemSlotHighlightReplayCoord:test_delivery_target_follows_client_role()
  local cases = {
    { role = { id = 1 }, target = 1 },
    { role = { id = 2 }, target = 2 },
    { role = nil, target = "全体" },
  }
  for _, case in ipairs(cases) do
    local captured = _capture(function()
      coord.deliver(replay.PLAN_REPLAY, { true, false, true, false, false })
    end, { role = case.role })
    _assert_eq(captured.targets[1], case.target, "宿主高亮事件投递目标")
  end
end

-- 发送失败:留诊断、不抛给调用方、不自动重试(记忆由 state 侧保留)。
function TestItemSlotHighlightReplayCoord:test_send_failure_keeps_diagnostic_without_retry()
  local captured = _capture(function()
    local ok = coord.deliver(replay.PLAN_REPLAY, { true, false, true, false, false })
    _assert_eq(ok, false, "发送失败返回 false 而不抛出")
  end, { role = { id = 1 }, fail = true })
  _assert_eq(#captured.warns >= 1, true, "保留宿主高亮事件发送失败诊断")
  -- 诊断必须带上宿主报错原文,否则真机上只剩「失败了」无从定位。
  _assert_eq(captured.warns[1]:find("host exploded", 1, true) ~= nil, true,
    "诊断带上宿主报错原文")
  _assert_eq(#captured.names, 0, "失败后没有事件被记为已投递")
  -- 失败不自动重试:统计真实尝试次数(含失败那次),一次 deliver 只该尝试一轮。
  -- 原先断言一个恒为 0 的局部变量,任何重试都发现不了(#596 审计)。
  _assert_eq(captured.attempts, 1, "未自动重试宿主高亮事件")
end

-- 未知计划断言失败(公开操作的入参守卫)。
function TestItemSlotHighlightReplayCoord:test_unknown_plan_asserts()
  _assert_eq(pcall(function()
    coord.deliver("不存在的计划", { true })
  end), false, "未知高亮计划应断言失败")
  _assert_eq(pcall(function()
    coord.deliver(replay.PLAN_REPLAY, nil)
  end), false, "replay 缺失槽位快照应断言失败")
end

return TestItemSlotHighlightReplayCoord
