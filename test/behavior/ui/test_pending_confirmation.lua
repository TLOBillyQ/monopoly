-- 二次确认屏状态深模块的纯状态行为规约（CONTEXT.md「二次确认屏」）。
-- 覆盖 enter/confirm/cancel × 两来源、重入与互斥语义（单记录：后 enter 顶掉
-- 已有记录）、item_phase_ask 的确认闩锁，以及 clear 的来源过滤。
local lu = require("luaunit")
local pending_confirmation = require("src.state.pending_confirmation")

-- 窄车道自备共享运行时端口基线（#217）：mutate 车道只跑相关
-- suite 子集,没有别的 spec 先装基线时第一个用例就被守卫判红;缺失才补装,
-- 全量车道基线在位时 no-op。
do
  local baseline_guard = require("test.support.runtime_baseline_guard")
  if #baseline_guard.missing_ports() > 0 then
    baseline_guard.restore()
  end
end

local SOURCES = {
  pending_confirmation.SOURCE_CHOICE_SELECT,
  pending_confirmation.SOURCE_ITEM_PHASE_ASK,
}

TestPendingConfirmation = {}

TestPendingConfirmation["test_ui 层入口是 state 深模块的同一引用(arch:ui 内部一律经 ui.state 引用)"] = function(self)
  -- src.ui.state.pending_confirmation 是纯 re-export 转接(turn_no_ui 的架构注释
  -- 在转接模块里);钉住同一引用,转接被改道(如复制一份实现)时此处即刻断裂。
  -- 清 package.loaded 重加载:转接 chunk 只在加载时执行,得在 case 内重放才能让
  -- 变异车道 suite-file map 归因到本 suite(原条目用后装回,不泄漏)。
  local name = "src.ui.state.pending_confirmation"
  local saved = package.loaded[name]
  package.loaded[name] = nil
  local reexport = require(name)
  package.loaded[name] = saved

  lu.assertIs(reexport, pending_confirmation)
end

TestPendingConfirmation["test_enter/confirm 各来源均建立并弹出同一条记录"] = function(self)
  for _, source in ipairs(SOURCES) do
    local state = {}
    local intent = { type = "ui_button", id = "item_slot_1" }
    lu.assertTrue(pending_confirmation.enter(state, source, {
      intent = intent,
      option_id = "opt1",
      source_screen = "market",
    }))

    lu.assertTrue(pending_confirmation.is_active(state))
    lu.assertTrue(pending_confirmation.is_source_active(state, source))
    lu.assertIs(pending_confirmation.active_source(state), source)
    lu.assertIs(pending_confirmation.stored_intent(state), intent)
    lu.assertIs(pending_confirmation.option_id(state), "opt1")
    lu.assertIs(pending_confirmation.source_screen(state), "market")

    local record = pending_confirmation.confirm(state)
    lu.assertIs(record.source, source)
    lu.assertIs(record.intent, intent)
    lu.assertIs(record.option_id, "opt1")
    lu.assertIs(record.source_screen, "market")
    lu.assertFalse(pending_confirmation.is_active(state))
    lu.assertNil(pending_confirmation.active_source(state))
  end
end

TestPendingConfirmation["test_enter/cancel 各来源均弹出记录且不留活动状态"] = function(self)
  for _, source in ipairs(SOURCES) do
    local state = {}
    lu.assertTrue(pending_confirmation.enter(state, source))
    local record = pending_confirmation.cancel(state)
    lu.assertIs(record.source, source)
    lu.assertFalse(pending_confirmation.is_active(state))
  end
end

TestPendingConfirmation["test_未激活时 confirm/cancel 返回 nil"] = function(self)
  local state = {}
  lu.assertNil(pending_confirmation.confirm(state))
  lu.assertNil(pending_confirmation.cancel(state))
  lu.assertFalse(pending_confirmation.is_active(state))
end

TestPendingConfirmation["test_非法参数的 enter 被拒绝"] = function(self)
  lu.assertFalse(pending_confirmation.enter(nil, pending_confirmation.SOURCE_CHOICE_SELECT))
  lu.assertFalse(pending_confirmation.enter({}, "unknown_source"))
  lu.assertFalse(pending_confirmation.enter({}, nil))
end

TestPendingConfirmation["test_互斥语义：单记录，另一来源 enter 顶掉已有记录"] = function(self)
  local state = {}
  local select_intent = { type = "choice_select", option_id = "opt1" }
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  lu.assertTrue(pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    intent = select_intent,
  }))

  -- 屏是同一块：后开的屏定义当前待确认内容，旧来源不再激活。
  lu.assertIs(pending_confirmation.active_source(state), pending_confirmation.SOURCE_CHOICE_SELECT)
  lu.assertFalse(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK))
  lu.assertIs(pending_confirmation.stored_intent(state), select_intent)

  -- confirm 只结算最新记录，不给被顶掉的 item_phase_ask 上闩锁。
  local record = pending_confirmation.confirm(state)
  lu.assertIs(record.source, pending_confirmation.SOURCE_CHOICE_SELECT)
  lu.assertFalse(pending_confirmation.is_item_phase_confirmed(state))
end

TestPendingConfirmation["test_重入语义：同来源再次 enter 覆盖 payload"] = function(self)
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    option_id = "opt1",
    source_screen = "player",
  })
  lu.assertTrue(pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    option_id = "opt2",
    source_screen = "market",
  }))
  lu.assertIs(pending_confirmation.option_id(state), "opt2")
  lu.assertIs(pending_confirmation.source_screen(state), "market")
end

TestPendingConfirmation["test_item_phase_ask 的 confirm 置确认闩锁，cancel/reset 清除"] = function(self)
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  lu.assertTrue(pending_confirmation.is_item_phase_confirmed(state))
  lu.assertFalse(pending_confirmation.is_active(state))

  -- 再次询问后取消：闩锁清除。
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.cancel(state)
  lu.assertFalse(pending_confirmation.is_item_phase_confirmed(state))

  -- reset 直接清除闩锁。
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  pending_confirmation.reset_item_phase_confirmed(state)
  lu.assertFalse(pending_confirmation.is_item_phase_confirmed(state))
end

TestPendingConfirmation["test_choice_select 的 confirm 不影响 item_phase 闩锁"] = function(self)
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT)
  pending_confirmation.confirm(state)
  lu.assertFalse(pending_confirmation.is_item_phase_confirmed(state))
end

TestPendingConfirmation["test_clear 按来源过滤：匹配才清除，nil 清除任意来源"] = function(self)
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

  pending_confirmation.clear(state, pending_confirmation.SOURCE_CHOICE_SELECT)
  lu.assertTrue(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK))

  pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  lu.assertFalse(pending_confirmation.is_active(state))

  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT)
  pending_confirmation.clear(state)
  lu.assertFalse(pending_confirmation.is_active(state))
end

TestPendingConfirmation["test_clear 丢弃记录但不动 item_phase 闩锁（force-skip 语义）"] = function(self)
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

  pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  lu.assertFalse(pending_confirmation.is_active(state))
  lu.assertTrue(pending_confirmation.is_item_phase_confirmed(state))
end

TestPendingConfirmation["test_弹出后不在 state 留残余键"] = function(self)
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    intent = { type = "choice_select", option_id = "opt1" },
  })
  pending_confirmation.cancel(state)
  lu.assertNil(state._pending_confirmation)

  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  pending_confirmation.reset_item_phase_confirmed(state)
  lu.assertNil(state._pending_confirmation)
end

TestPendingConfirmation["test_空表/非表 state 上的读接口安全返回未激活"] = function(self)
  lu.assertFalse(pending_confirmation.is_active(nil))
  lu.assertFalse(pending_confirmation.is_source_active(nil, pending_confirmation.SOURCE_CHOICE_SELECT))
  lu.assertNil(pending_confirmation.active_source({}))
  lu.assertNil(pending_confirmation.stored_intent({}))
  lu.assertNil(pending_confirmation.option_id({}))
  lu.assertNil(pending_confirmation.source_screen({}))
  lu.assertFalse(pending_confirmation.is_item_phase_confirmed({}))
  pending_confirmation.reset_item_phase_confirmed({})
  pending_confirmation.clear(nil)
end


return TestPendingConfirmation
