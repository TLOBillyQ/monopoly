local tip_queue = require("src.foundation.tips")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _reset()
  tip_queue.clear()
  tip_queue.configure_runtime({ clear_presenter = true, clear_scheduler = true, test_mode = false })
end

-- configure_runtime aliases and clear flags









-- enqueue: deduplication




-- has_blocking_pending





-- _schedule_release paths (via enqueue + presenter)

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
end)
