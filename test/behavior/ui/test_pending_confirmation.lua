require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- 二次确认屏状态深模块的纯状态行为规约（GLOSSARY.md「二次确认屏」）。
-- 覆盖 enter/confirm/cancel × 两来源、重入与互斥语义（单记录：后 enter 顶掉
-- 已有记录）、item_phase_ask 的确认闩锁，以及 clear 的来源过滤。
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
describe("TestPendingConfirmation", function()
it("test_ui 层入口是 state 深模块的同一引用(arch:ui 内部一律经 ui.state 引用)", function()
  -- src.ui.state.pending_confirmation 是纯 re-export 转接(turn_no_ui 的架构注释
  -- 在转接模块里);钉住同一引用,转接被改道(如复制一份实现)时此处即刻断裂。
  -- 清 package.loaded 重加载:转接 chunk 只在加载时执行,得在 case 内重放才能让
  -- 变异车道 suite-file map 归因到本 suite(原条目用后装回,不泄漏)。
  local name = "src.ui.state.pending_confirmation"
  local saved = package.loaded[name]
  package.loaded[name] = nil
  local reexport = require(name)
  package.loaded[name] = saved

  luassert.is.equal(pending_confirmation, reexport)
end)

it("test_enter/confirm 各来源均建立并弹出同一条记录", function()
  for _, source in ipairs(SOURCES) do
    local state = {}
    local intent = { type = "ui_button", id = "item_slot_1" }
    luassert.is_true(pending_confirmation.enter(state, source, {
      intent = intent,
      option_id = "opt1",
      source_screen = "market",
    }))

    luassert.is_true(pending_confirmation.is_active(state))
    luassert.is_true(pending_confirmation.is_source_active(state, source))
    luassert.is.equal(source, pending_confirmation.active_source(state))
    luassert.is.equal(intent, pending_confirmation.stored_intent(state))
    luassert.is.equal("opt1", pending_confirmation.option_id(state))
    luassert.is.equal("market", pending_confirmation.source_screen(state))

    local record = pending_confirmation.confirm(state)
    luassert.is.equal(source, record.source)
    luassert.is.equal(intent, record.intent)
    luassert.is.equal("opt1", record.option_id)
    luassert.is.equal("market", record.source_screen)
    luassert.is_false(pending_confirmation.is_active(state))
    luassert.is_nil(pending_confirmation.active_source(state))
  end
end)

it("test_enter/cancel 各来源均弹出记录且不留活动状态", function()
  for _, source in ipairs(SOURCES) do
    local state = {}
    luassert.is_true(pending_confirmation.enter(state, source))
    local record = pending_confirmation.cancel(state)
    luassert.is.equal(source, record.source)
    luassert.is_false(pending_confirmation.is_active(state))
  end
end)

it("test_未激活时 confirm/cancel 返回 nil", function()
  local state = {}
  luassert.is_nil(pending_confirmation.confirm(state))
  luassert.is_nil(pending_confirmation.cancel(state))
  luassert.is_false(pending_confirmation.is_active(state))
end)

it("test_非法参数的 enter 被拒绝", function()
  luassert.is_false(pending_confirmation.enter(nil, pending_confirmation.SOURCE_CHOICE_SELECT))
  luassert.is_false(pending_confirmation.enter({}, "unknown_source"))
  luassert.is_false(pending_confirmation.enter({}, nil))
end)

it("test_互斥语义：单记录，另一来源 enter 顶掉已有记录", function()
  local state = {}
  local select_intent = { type = "choice_select", option_id = "opt1" }
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  luassert.is_true(pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    intent = select_intent,
  }))

  -- 屏是同一块：后开的屏定义当前待确认内容，旧来源不再激活。
  luassert.is.equal(pending_confirmation.SOURCE_CHOICE_SELECT, pending_confirmation.active_source(state))
  luassert.is_false(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK))
  luassert.is.equal(select_intent, pending_confirmation.stored_intent(state))

  -- confirm 只结算最新记录，不给被顶掉的 item_phase_ask 上闩锁。
  local record = pending_confirmation.confirm(state)
  luassert.is.equal(pending_confirmation.SOURCE_CHOICE_SELECT, record.source)
  luassert.is_false(pending_confirmation.is_item_phase_confirmed(state))
end)

it("test_重入语义：同来源再次 enter 覆盖 payload", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    option_id = "opt1",
    source_screen = "player",
  })
  luassert.is_true(pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    option_id = "opt2",
    source_screen = "market",
  }))
  luassert.is.equal("opt2", pending_confirmation.option_id(state))
  luassert.is.equal("market", pending_confirmation.source_screen(state))
end)

it("test_item_phase_ask 的 confirm 置确认闩锁，cancel/reset 清除", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  luassert.is_true(pending_confirmation.is_item_phase_confirmed(state))
  luassert.is_false(pending_confirmation.is_active(state))

  -- 再次询问后取消：闩锁清除。
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.cancel(state)
  luassert.is_false(pending_confirmation.is_item_phase_confirmed(state))

  -- reset 直接清除闩锁。
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  pending_confirmation.reset_item_phase_confirmed(state)
  luassert.is_false(pending_confirmation.is_item_phase_confirmed(state))
end)

it("test_choice_select 的 confirm 不影响 item_phase 闩锁", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT)
  pending_confirmation.confirm(state)
  luassert.is_false(pending_confirmation.is_item_phase_confirmed(state))
end)

it("test_clear 按来源过滤：匹配才清除，nil 清除任意来源", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

  pending_confirmation.clear(state, pending_confirmation.SOURCE_CHOICE_SELECT)
  luassert.is_true(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK))

  pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  luassert.is_false(pending_confirmation.is_active(state))

  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT)
  pending_confirmation.clear(state)
  luassert.is_false(pending_confirmation.is_active(state))
end)

it("test_clear 丢弃记录但不动 item_phase 闩锁（force-skip 语义）", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

  pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  luassert.is_false(pending_confirmation.is_active(state))
  luassert.is_true(pending_confirmation.is_item_phase_confirmed(state))
end)

it("test_弹出后不在 state 留残余键", function()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    intent = { type = "choice_select", option_id = "opt1" },
  })
  pending_confirmation.cancel(state)
  luassert.is_nil(state._pending_confirmation)

  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  pending_confirmation.confirm(state)
  pending_confirmation.reset_item_phase_confirmed(state)
  luassert.is_nil(state._pending_confirmation)
end)

it("test_空表/非表 state 上的读接口安全返回未激活", function()
  luassert.is_false(pending_confirmation.is_active(nil))
  luassert.is_false(pending_confirmation.is_source_active(nil, pending_confirmation.SOURCE_CHOICE_SELECT))
  luassert.is_nil(pending_confirmation.active_source({}))
  luassert.is_nil(pending_confirmation.stored_intent({}))
  luassert.is_nil(pending_confirmation.option_id({}))
  luassert.is_nil(pending_confirmation.source_screen({}))
  luassert.is_false(pending_confirmation.is_item_phase_confirmed({}))
  pending_confirmation.reset_item_phase_confirmed({})
  pending_confirmation.clear(nil)
end)


end)
