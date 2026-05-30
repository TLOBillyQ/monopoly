local tip_queue = require("src.foundation.tips")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _reset()
  tip_queue.clear()
  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
    test_mode = false,
    event_tip_fast_backlog_threshold = 2,
    event_tip_fast_seconds = 0.5,
  })
end

describe("domain tip queue coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("configure_runtime clear_presenter", function()
    _reset()
    tip_queue.configure_runtime({ presenter = function() end })
    tip_queue.configure_runtime({ clear_presenter = true })
    _assert_eq(tip_queue.runtime.presenter, nil, "clear_presenter should remove presenter")
    _reset()
  end)

  it("configure_runtime show_tip alias", function()
    _reset()
    local fn = function() end
    tip_queue.configure_runtime({ show_tip = fn })
    _assert_eq(tip_queue.runtime.presenter, fn, "show_tip should alias presenter")
    _reset()
  end)

  it("configure_runtime tip_presenter alias", function()
    _reset()
    local fn = function() end
    tip_queue.configure_runtime({ tip_presenter = fn })
    _assert_eq(tip_queue.runtime.presenter, fn, "tip_presenter should alias presenter")
    _reset()
  end)

  it("configure_runtime clear_scheduler", function()
    _reset()
    tip_queue.configure_runtime({ scheduler = function() end })
    tip_queue.configure_runtime({ clear_scheduler = true })
    _assert_eq(tip_queue.runtime.scheduler, nil, "clear_scheduler should remove scheduler")
    _reset()
  end)

  it("configure_runtime schedule alias", function()
    _reset()
    local fn = function() end
    tip_queue.configure_runtime({ schedule = fn })
    _assert_eq(tip_queue.runtime.scheduler, fn, "schedule should alias scheduler")
    _reset()
  end)

  it("configure_runtime invalid presenter asserts", function()
    _reset()
    local ok, err = pcall(function()
      tip_queue.configure_runtime({ presenter = "not_a_function" })
    end)
    _assert_eq(ok, false, "non-function presenter should assert")
    assert(tostring(err):find("function", 1, true), "error should mention function: " .. tostring(err))
    _reset()
  end)

  it("configure_runtime invalid scheduler asserts", function()
    _reset()
    local ok = pcall(function()
      tip_queue.configure_runtime({ scheduler = 42 })
    end)
    _assert_eq(ok, false, "non-function scheduler should assert")
    _reset()
  end)

  it("release_tip advances to next pending", function()
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
  end)

  it("enqueue nil text returns false", function()
    _reset()
    local ok = tip_queue.enqueue({ text = nil, duration = 1.0 })
    _assert_eq(ok, false, "nil text should return false")
    _reset()
  end)

  it("enqueue dedup by active_tip", function()
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
  end)

  it("enqueue dedup by pending", function()
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
  end)

  it("has_blocking_pending non-inter_turn returns false", function()
    _reset()
    tip_queue.enqueue({ text = "msg", duration = 1.0, blocks_inter_turn = true })
    _assert_eq(tip_queue.has_blocking_pending("move"), false,
      "non-inter_turn phase should return false regardless")
    _reset()
  end)

  it("has_blocking_pending no blocking tip returns false", function()
    _reset()
    tip_queue.enqueue({ text = "msg", duration = 1.0, blocks_inter_turn = false })
    _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false,
      "non-blocking tip should return false")
    _reset()
  end)

  it("has_blocking_pending blocking active_tip returns true", function()
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
  end)

  it("has_blocking_pending blocking tip in pending", function()
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
  end)

  it("schedule_release no scheduler calls release immediately", function()
    _reset()
    tip_queue.configure_runtime({
      presenter = function() end,
    })
    tip_queue.enqueue({ text = "tip", duration = 0.5 })
    _assert_eq(tip_queue.active_tip, nil,
      "without scheduler, tip should be released immediately (active_tip cleared)")
    _reset()
  end)

  it("schedule_release scheduler invokes callback directly", function()
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
  end)

  it("schedule_release scheduler defers with test_mode releases tip", function()
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
  end)

  it("schedule_release scheduler defers no test_mode keeps tip", function()
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
  end)

  it("snapshot reflects empty queue state", function()
    _reset()
    local s = tip_queue.snapshot()
    _assert_eq(s.has_presenter, false, "no presenter configured")
    _assert_eq(s.has_scheduler, false, "no scheduler configured")
    _assert_eq(s.pending_count, 0, "no pending tips")
    _assert_eq(s.active_text, nil, "no active tip")
    _assert_eq(type(s.epoch), "number", "epoch is a number")
    _assert_eq(s.test_mode, false, "test_mode defaults false")
    _reset()
  end)

  it("snapshot reflects configured presenter and active tip", function()
    _reset()
    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function() return true end,
    })
    tip_queue.enqueue({ text = "hello", duration = 1.0 })
    tip_queue.enqueue({ text = "world", duration = 1.0 })
    local s = tip_queue.snapshot()
    _assert_eq(s.has_presenter, true, "presenter is set")
    _assert_eq(s.has_scheduler, true, "scheduler is set")
    _assert_eq(s.active_text, "hello", "active tip text")
    _assert_eq(s.pending_count, 1, "one tip in pending")
    _reset()
  end)

  it("clear increments epoch by exactly 1 to invalidate stale releases", function()
    _reset()
    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function() return true end,
    })
    tip_queue.enqueue({ text = "tip", duration = 1.0 })
    local epoch_before = tip_queue.epoch
    tip_queue.clear()
    local epoch_after = tip_queue.epoch
    _assert_eq(epoch_after - epoch_before, 1, "clear must increment epoch by exactly 1")
    _reset()
  end)

  it("normalize_duration defaults to 2.0 for zero duration", function()
    _reset()
    local shown = {}
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
      scheduler = function() return true end,
    })
    tip_queue.enqueue({ text = "zero_dur", duration = 0 })
    _assert_eq(#shown, 1, "tip with zero duration should still be presented")
    _assert_eq(shown[1].duration, 2.0, "zero duration should default to 2.0")
    _reset()
  end)

  it("normalize_duration defaults to 2.0 for negative duration", function()
    _reset()
    local shown = {}
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
      scheduler = function() return true end,
    })
    tip_queue.enqueue({ text = "neg_dur", duration = -3.0 })
    _assert_eq(#shown, 1, "tip with negative duration should still be presented")
    _assert_eq(shown[1].duration, 2.0, "negative duration should default to 2.0")
    _reset()
  end)

  it("backlog_acceleration uses fast_seconds when backlog reaches threshold", function()
    _reset()
    local timers = {}
    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
      event_tip_fast_backlog_threshold = 1,
      event_tip_fast_seconds = 0.5,
    })
    tip_queue.enqueue({ text = "a", duration = 5.0 })
    tip_queue.enqueue({ text = "b", duration = 5.0 })
    tip_queue.enqueue({ text = "c", duration = 5.0 })
    _assert_eq(#timers, 1, "only first tip should be scheduled (others pending)")
    timers[1].fn()
    _assert_eq(#timers, 2, "second tip scheduled after first releases")
    _assert_eq(timers[2].delay, 0.5, "backlog at threshold should apply fast_seconds")
    _reset()
  end)

  it("backlog_acceleration preserves duration when backlog below threshold", function()
    _reset()
    local timers = {}
    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
      event_tip_fast_backlog_threshold = 2,
      event_tip_fast_seconds = 0.5,
    })
    tip_queue.enqueue({ text = "a", duration = 5.0 })
    tip_queue.enqueue({ text = "b", duration = 5.0 })
    tip_queue.enqueue({ text = "c", duration = 5.0 })
    timers[1].fn()
    _assert_eq(timers[2].delay, 5.0, "backlog below threshold should preserve duration")
    _reset()
  end)

  it("backlog_acceleration preserves duration when fast_seconds exceeds duration", function()
    _reset()
    local timers = {}
    tip_queue.configure_runtime({
      presenter = function() end,
      scheduler = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
      event_tip_fast_backlog_threshold = 1,
      event_tip_fast_seconds = 10.0,
    })
    tip_queue.enqueue({ text = "a", duration = 3.0 })
    tip_queue.enqueue({ text = "b", duration = 3.0 })
    timers[1].fn()
    _assert_eq(timers[2].delay, 3.0, "fast_seconds > duration should preserve shorter duration")
    _reset()
  end)

  it("schedule_release calls release_fn exactly once when scheduler invokes synchronously", function()
    _reset()
    local presented = {}
    tip_queue.configure_runtime({
      presenter = function(text)
        presented[#presented + 1] = text
      end,
      scheduler = function(_, fn)
        fn()
      end,
    })
    tip_queue.enqueue({ text = "sync1", duration = 1.0 })
    tip_queue.enqueue({ text = "sync2", duration = 1.0 })
    _assert_eq(#presented, 2, "both tips should be presented")
    _assert_eq(presented[1], "sync1", "first tip presented")
    _assert_eq(presented[2], "sync2", "second tip presented")
    _assert_eq(tip_queue.active_tip, nil, "queue drained after synchronous release")
    _reset()
  end)

  it("apply_numeric_runtime_field ignores non-numeric values", function()
    _reset()
    tip_queue.configure_runtime({
      event_tip_fast_backlog_threshold = "not_a_number",
      event_tip_fast_seconds = nil,
    })
    _assert_eq(tip_queue.runtime.event_tip_fast_backlog_threshold, 2,
      "non-numeric threshold should not update runtime field")
    _assert_eq(tip_queue.runtime.event_tip_fast_seconds, 0.5,
      "nil seconds should not update runtime field")
    _reset()
  end)

  it("apply_numeric_runtime_field accepts numeric values", function()
    _reset()
    tip_queue.configure_runtime({
      event_tip_fast_backlog_threshold = 5,
      event_tip_fast_seconds = 1.5,
    })
    _assert_eq(tip_queue.runtime.event_tip_fast_backlog_threshold, 5,
      "numeric threshold should update runtime field")
    _assert_eq(tip_queue.runtime.event_tip_fast_seconds, 1.5,
      "numeric seconds should update runtime field")
    _reset()
  end)

  it("present_tip handles presenter error and continues queue", function()
    _reset()
    local call_count = 0
    local timers = {}
    tip_queue.configure_runtime({
      presenter = function()
        call_count = call_count + 1
        if call_count == 1 then
          error("presenter boom")
        end
      end,
      scheduler = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
    })
    tip_queue.enqueue({ text = "fail", duration = 1.0 })
    tip_queue.enqueue({ text = "recover", duration = 1.0 })
    _assert_eq(call_count, 1, "first tip should be presented (and error)")
    timers[1].fn()
    _assert_eq(call_count, 2, "second tip should be presented after first releases")
    _reset()
  end)
end)
