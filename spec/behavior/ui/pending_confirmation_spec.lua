-- 二次确认屏状态深模块的纯状态行为规约（CONTEXT.md「二次确认屏」）。
-- 覆盖 enter/confirm/cancel × 三来源、重入与互斥语义（单记录：后 enter 顶掉
-- 已有记录）、item_phase_ask 的确认闩锁，以及 clear 的来源过滤。
local pending_confirmation = require("src.state.pending_confirmation")

local SOURCES = {
  pending_confirmation.SOURCE_CHOICE_SELECT,
  pending_confirmation.SOURCE_ITEM_SLOT,
  pending_confirmation.SOURCE_ITEM_PHASE_ASK,
}

describe("pending_confirmation 深模块", function()
  it("enter/confirm 三来源均建立并弹出同一条记录", function()
    for _, source in ipairs(SOURCES) do
      local state = {}
      local intent = { type = "ui_button", id = "item_slot_1" }
      assert.is_true(pending_confirmation.enter(state, source, {
        intent = intent,
        option_id = "opt1",
        source_screen = "market",
      }))

      assert.is_true(pending_confirmation.is_active(state))
      assert.is_true(pending_confirmation.is_source_active(state, source))
      assert.equals(source, pending_confirmation.active_source(state))
      assert.equals(intent, pending_confirmation.stored_intent(state))
      assert.equals("opt1", pending_confirmation.option_id(state))
      assert.equals("market", pending_confirmation.source_screen(state))

      local record = pending_confirmation.confirm(state)
      assert.equals(source, record.source)
      assert.equals(intent, record.intent)
      assert.equals("opt1", record.option_id)
      assert.equals("market", record.source_screen)
      assert.is_false(pending_confirmation.is_active(state))
      assert.is_nil(pending_confirmation.active_source(state))
    end
  end)

  it("enter/cancel 三来源均弹出记录且不留活动状态", function()
    for _, source in ipairs(SOURCES) do
      local state = {}
      assert.is_true(pending_confirmation.enter(state, source))
      local record = pending_confirmation.cancel(state)
      assert.equals(source, record.source)
      assert.is_false(pending_confirmation.is_active(state))
    end
  end)

  it("未激活时 confirm/cancel 返回 nil", function()
    local state = {}
    assert.is_nil(pending_confirmation.confirm(state))
    assert.is_nil(pending_confirmation.cancel(state))
    assert.is_false(pending_confirmation.is_active(state))
  end)

  it("非法参数的 enter 被拒绝", function()
    assert.is_false(pending_confirmation.enter(nil, pending_confirmation.SOURCE_ITEM_SLOT))
    assert.is_false(pending_confirmation.enter({}, "unknown_source"))
    assert.is_false(pending_confirmation.enter({}, nil))
  end)

  it("互斥语义：单记录，另一来源 enter 顶掉已有记录", function()
    local state = {}
    local slot_intent = { type = "ui_button", id = "item_slot_2" }
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    assert.is_true(pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_SLOT, {
      intent = slot_intent,
    }))

    -- 屏是同一块：后开的屏定义当前待确认内容，旧来源不再激活。
    assert.equals(pending_confirmation.SOURCE_ITEM_SLOT, pending_confirmation.active_source(state))
    assert.is_false(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK))
    assert.equals(slot_intent, pending_confirmation.stored_intent(state))

    -- confirm 只结算最新记录，不给被顶掉的 item_phase_ask 上闩锁。
    local record = pending_confirmation.confirm(state)
    assert.equals(pending_confirmation.SOURCE_ITEM_SLOT, record.source)
    assert.is_false(pending_confirmation.is_item_phase_confirmed(state))
  end)

  it("重入语义：同来源再次 enter 覆盖 payload", function()
    local state = {}
    pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
      option_id = "opt1",
      source_screen = "player",
    })
    assert.is_true(pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
      option_id = "opt2",
      source_screen = "market",
    }))
    assert.equals("opt2", pending_confirmation.option_id(state))
    assert.equals("market", pending_confirmation.source_screen(state))
  end)

  it("item_phase_ask 的 confirm 置确认闩锁，cancel/reset 清除", function()
    local state = {}
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    pending_confirmation.confirm(state)
    assert.is_true(pending_confirmation.is_item_phase_confirmed(state))
    assert.is_false(pending_confirmation.is_active(state))

    -- 再次询问后取消：闩锁清除。
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    pending_confirmation.cancel(state)
    assert.is_false(pending_confirmation.is_item_phase_confirmed(state))

    -- reset 直接清除闩锁。
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    pending_confirmation.confirm(state)
    pending_confirmation.reset_item_phase_confirmed(state)
    assert.is_false(pending_confirmation.is_item_phase_confirmed(state))
  end)

  it("choice_select / item_slot 的 confirm 不影响 item_phase 闩锁", function()
    local state = {}
    pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT)
    pending_confirmation.confirm(state)
    assert.is_false(pending_confirmation.is_item_phase_confirmed(state))

    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_SLOT)
    pending_confirmation.confirm(state)
    assert.is_false(pending_confirmation.is_item_phase_confirmed(state))
  end)

  it("clear 按来源过滤：匹配才清除，nil 清除任意来源", function()
    local state = {}
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

    pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_SLOT)
    assert.is_true(pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK))

    pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    assert.is_false(pending_confirmation.is_active(state))

    pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT)
    pending_confirmation.clear(state)
    assert.is_false(pending_confirmation.is_active(state))
  end)

  it("clear 丢弃记录但不动 item_phase 闩锁（force-skip 语义）", function()
    local state = {}
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    pending_confirmation.confirm(state)
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)

    pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    assert.is_false(pending_confirmation.is_active(state))
    assert.is_true(pending_confirmation.is_item_phase_confirmed(state))
  end)

  it("弹出后不在 state 留残余键", function()
    local state = {}
    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_SLOT, {
      intent = { type = "ui_button", id = "item_slot_1" },
    })
    pending_confirmation.cancel(state)
    assert.is_nil(state._pending_confirmation)

    pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    pending_confirmation.confirm(state)
    pending_confirmation.reset_item_phase_confirmed(state)
    assert.is_nil(state._pending_confirmation)
  end)

  it("空表/非表 state 上的读接口安全返回未激活", function()
    assert.is_false(pending_confirmation.is_active(nil))
    assert.is_false(pending_confirmation.is_source_active(nil, pending_confirmation.SOURCE_ITEM_SLOT))
    assert.is_nil(pending_confirmation.active_source({}))
    assert.is_nil(pending_confirmation.stored_intent({}))
    assert.is_nil(pending_confirmation.option_id({}))
    assert.is_nil(pending_confirmation.source_screen({}))
    assert.is_false(pending_confirmation.is_item_phase_confirmed({}))
    pending_confirmation.reset_item_phase_confirmed({})
    pending_confirmation.clear(nil)
  end)
end)
