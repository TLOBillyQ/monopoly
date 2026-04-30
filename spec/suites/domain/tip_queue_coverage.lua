local tip_queue = require("src.foundation.coordination.tip_queue")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _reset()
  tip_queue.clear()
  tip_queue.configure_runtime({ clear_presenter = true, clear_scheduler = true, test_mode = false })
end

-- configure_runtime aliases and clear flags

local function test_configure_runtime_clear_presenter()
  _reset()
  tip_queue.configure_runtime({ presenter = function() end })
  tip_queue.configure_runtime({ clear_presenter = true })
  _assert_eq(tip_queue.runtime.presenter, nil, "clear_presenter should remove presenter")
  _reset()
end

local function test_configure_runtime_show_tip_alias()
  _reset()
  local fn = function() end
  tip_queue.configure_runtime({ show_tip = fn })
  _assert_eq(tip_queue.runtime.presenter, fn, "show_tip should alias presenter")
  _reset()
end

local function test_configure_runtime_tip_presenter_alias()
  _reset()
  local fn = function() end
  tip_queue.configure_runtime({ tip_presenter = fn })
  _assert_eq(tip_queue.runtime.presenter, fn, "tip_presenter should alias presenter")
  _reset()
end

local function test_configure_runtime_clear_scheduler()
  _reset()
  tip_queue.configure_runtime({ scheduler = function() end })
  tip_queue.configure_runtime({ clear_scheduler = true })
  _assert_eq(tip_queue.runtime.scheduler, nil, "clear_scheduler should remove scheduler")
  _reset()
end

local function test_configure_runtime_schedule_alias()
  _reset()
  local fn = function() end
  tip_queue.configure_runtime({ schedule = fn })
  _assert_eq(tip_queue.runtime.scheduler, fn, "schedule should alias scheduler")
  _reset()
end

local function test_configure_runtime_invalid_presenter_asserts()
  _reset()
  local ok, err = pcall(function()
    tip_queue.configure_runtime({ presenter = "not_a_function" })
  end)
  _assert_eq(ok, false, "non-function presenter should assert")
  assert(tostring(err):find("function", 1, true), "error should mention function: " .. tostring(err))
  _reset()
end

local function test_configure_runtime_invalid_scheduler_asserts()
  _reset()
  local ok = pcall(function()
    tip_queue.configure_runtime({ scheduler = 42 })
  end)
  _assert_eq(ok, false, "non-function scheduler should assert")
  _reset()
end

local function test_release_tip_advances_to_next_pending()
  _reset()
  local release_cb = nil
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function(_, fn)
      release_cb = fn
      return true
    end,
  })
  tip_queue.enqueue({ text = "first", duration = 1.0 })
  tip_queue.enqueue({ text = "second", duration = 1.0 })
  assert(tip_queue.active_tip ~= nil, "first tip should be active")
  assert(#tip_queue.pending == 1, "second tip should be in pending")
  release_cb()
  assert(tip_queue.active_tip ~= nil, "second tip should become active after release")
  assert(tip_queue.active_tip.text == "second", "second tip should be dispatched")
  _reset()
end

-- enqueue: deduplication

local function test_enqueue_nil_text_returns_false()
  _reset()
  local ok = tip_queue.enqueue({ text = nil, duration = 1.0 })
  _assert_eq(ok, false, "nil text should return false")
  _reset()
end

local function test_enqueue_dedup_by_active_tip()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function() return true end,
  })
  local ok1 = tip_queue.enqueue({ text = "msg", duration = 1.0, dedupe_key = "k1" })
  _assert_eq(ok1, true, "first enqueue should succeed")
  assert(tip_queue.active_tip ~= nil, "tip should remain active with deferring scheduler")
  local ok2 = tip_queue.enqueue({ text = "msg2", duration = 1.0, dedupe_key = "k1" })
  _assert_eq(ok2, false, "duplicate key matching active_tip should return false")
  _reset()
end

local function test_enqueue_dedup_by_pending()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function()
      return true
    end,
  })
  tip_queue.enqueue({ text = "tip1", duration = 1.0 })
  local ok = tip_queue.enqueue({ text = "tip2", duration = 1.0, dedupe_key = "pending_k" })
  _assert_eq(ok, true, "different key should be enqueued")
  local ok2 = tip_queue.enqueue({ text = "tip3", duration = 1.0, dedupe_key = "pending_k" })
  _assert_eq(ok2, false, "same key in pending should be deduped")
  _reset()
end

-- has_blocking_pending

local function test_has_blocking_pending_non_inter_turn_returns_false()
  _reset()
  tip_queue.enqueue({ text = "msg", duration = 1.0, blocks_inter_turn = true })
  _assert_eq(tip_queue.has_blocking_pending("move"), false,
    "non-inter_turn phase should return false regardless")
  _reset()
end

local function test_has_blocking_pending_no_blocking_tip_returns_false()
  _reset()
  tip_queue.enqueue({ text = "msg", duration = 1.0, blocks_inter_turn = false })
  _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false,
    "non-blocking tip should return false")
  _reset()
end

local function test_has_blocking_pending_blocking_active_tip_returns_true()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function() return true end,
  })
  tip_queue.enqueue({ text = "msg", duration = 1.0, blocks_inter_turn = true })
  assert(tip_queue.active_tip ~= nil, "tip should be active with deferring scheduler")
  _assert_eq(tip_queue.has_blocking_pending("inter_turn"), true,
    "blocking active_tip should return true")
  _reset()
end

local function test_has_blocking_pending_blocking_tip_in_pending()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function()
      return true
    end,
  })
  tip_queue.enqueue({ text = "first", duration = 1.0 })
  tip_queue.enqueue({ text = "blocking", duration = 1.0, blocks_inter_turn = true })
  _assert_eq(tip_queue.has_blocking_pending("inter_turn"), true,
    "blocking tip in pending should return true")
  _reset()
end

-- _schedule_release paths (via enqueue + presenter)

local function test_schedule_release_no_scheduler_calls_release_immediately()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
  })
  tip_queue.enqueue({ text = "tip", duration = 0.5 })
  _assert_eq(tip_queue.active_tip, nil,
    "without scheduler, tip should be released immediately (active_tip cleared)")
  _reset()
end

local function test_schedule_release_scheduler_invokes_callback_directly()
  _reset()
  local scheduler_called = false
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function(_, fn)
      scheduler_called = true
      fn()
    end,
  })
  tip_queue.enqueue({ text = "tip", duration = 0.5 })
  _assert_eq(scheduler_called, true, "scheduler should be called")
  _assert_eq(tip_queue.active_tip, nil, "tip released when scheduler invokes callback")
  _reset()
end

local function test_schedule_release_scheduler_defers_release_returns_true_test_mode()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function()
      return true
    end,
    test_mode = true,
  })
  tip_queue.enqueue({ text = "tip", duration = 0.5 })
  _assert_eq(tip_queue.active_tip, nil,
    "in test_mode, returning true from scheduler should still release tip")
  _reset()
end

local function test_schedule_release_scheduler_defers_no_test_mode_keeps_tip()
  _reset()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function()
      return true
    end,
    test_mode = false,
  })
  tip_queue.enqueue({ text = "tip", duration = 0.5 })
  assert(tip_queue.active_tip ~= nil,
    "without test_mode, returning true from scheduler should keep tip active")
  _reset()
end

return {
  name = "domain tip queue coverage",
  tests = {
    { name = "configure_runtime clear_presenter", run = test_configure_runtime_clear_presenter },
    { name = "configure_runtime show_tip alias", run = test_configure_runtime_show_tip_alias },
    { name = "configure_runtime tip_presenter alias", run = test_configure_runtime_tip_presenter_alias },
    { name = "configure_runtime clear_scheduler", run = test_configure_runtime_clear_scheduler },
    { name = "configure_runtime schedule alias", run = test_configure_runtime_schedule_alias },
    { name = "configure_runtime invalid presenter asserts", run = test_configure_runtime_invalid_presenter_asserts },
    { name = "configure_runtime invalid scheduler asserts", run = test_configure_runtime_invalid_scheduler_asserts },
    { name = "release_tip advances to next pending", run = test_release_tip_advances_to_next_pending },
    { name = "enqueue nil text returns false", run = test_enqueue_nil_text_returns_false },
    { name = "enqueue dedup by active_tip", run = test_enqueue_dedup_by_active_tip },
    { name = "enqueue dedup by pending", run = test_enqueue_dedup_by_pending },
    { name = "has_blocking_pending non-inter_turn returns false", run = test_has_blocking_pending_non_inter_turn_returns_false },
    { name = "has_blocking_pending no blocking tip returns false", run = test_has_blocking_pending_no_blocking_tip_returns_false },
    { name = "has_blocking_pending blocking active_tip returns true", run = test_has_blocking_pending_blocking_active_tip_returns_true },
    { name = "has_blocking_pending blocking tip in pending", run = test_has_blocking_pending_blocking_tip_in_pending },
    { name = "schedule_release no scheduler calls release immediately", run = test_schedule_release_no_scheduler_calls_release_immediately },
    { name = "schedule_release scheduler invokes callback directly", run = test_schedule_release_scheduler_invokes_callback_directly },
    { name = "schedule_release scheduler defers with test_mode releases tip", run = test_schedule_release_scheduler_defers_release_returns_true_test_mode },
    { name = "schedule_release scheduler defers no test_mode keeps tip", run = test_schedule_release_scheduler_defers_no_test_mode_keeps_tip },
  },
}
