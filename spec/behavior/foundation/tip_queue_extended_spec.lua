local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local tip_queue = require("src.foundation.tips")

local function _reset_tip_queue()
  tip_queue.clear()
  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
    test_mode = false,
    event_tip_fast_backlog_threshold = 2,
    event_tip_fast_seconds = 0.5,
  })
end

local function _with_queue_runtime(fn)
  _reset_tip_queue()
  local ok, err = pcall(fn)
  _reset_tip_queue()
  if not ok then
    error(err)
  end
end

describe("suites.runtime.misc_tip_queue", function()
  it("tip_queue_uses_fifo_queue_without_override", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      tip_queue.enqueue({
        text = "A",
        duration = 3.0,
        dedupe_key = "tip_a",
      })
      tip_queue.enqueue({
        text = "B",
        duration = 2.0,
        dedupe_key = "tip_b",
      })

      _assert_eq(#shown, 1, "second tip should wait until the first tip releases")
      _assert_eq(shown[1].text, "A", "first shown tip should be A")
      _assert_eq(#timers, 1, "first tip should schedule one release timer")
      _assert_eq(timers[1].delay, 3.0, "first tip release timer should match duration")

      timers[1].fn()

      _assert_eq(#shown, 2, "second tip should show after first tip release")
      _assert_eq(shown[2].text, "B", "second shown tip should be B")
      _assert_eq(#timers, 2, "second tip should schedule another release timer")
      _assert_eq(timers[2].delay, 2.0, "second tip release timer should match duration")
    end)
  end)

  it("tip_queue_dedupes_same_semantic_key_across_active_and_pending", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      _assert_eq(tip_queue.enqueue({
        text = "active",
        duration = 3.0,
        dedupe_key = "same_semantic_tip",
      }), true, "first semantic tip should enqueue")
      _assert_eq(tip_queue.enqueue({
        text = "duplicate_active",
        duration = 1.0,
        dedupe_key = "same_semantic_tip",
      }), false, "active duplicate should be dropped")
      _assert_eq(tip_queue.enqueue({
        text = "queued",
        duration = 2.0,
        dedupe_key = "other_semantic_tip",
      }), true, "different semantic tip should enqueue")
      _assert_eq(tip_queue.enqueue({
        text = "duplicate_queued",
        duration = 1.0,
        dedupe_key = "other_semantic_tip",
      }), false, "queued duplicate should be dropped")

      _assert_eq(#shown, 1, "only the active tip should show immediately")
      _assert_eq(#timers, 1, "only one timer should exist before release")

      timers[1].fn()

      _assert_eq(#shown, 2, "queued semantic tip should show after release")
      _assert_eq(shown[2].text, "queued", "first queued semantic tip should win")
    end)
  end)

  it("tip_queue_only_blocks_inter_turn_for_blocking_tips", function()
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function() end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      tip_queue.enqueue({
        text = "non_blocking",
        duration = 3.0,
        dedupe_key = "non_blocking_tip",
        blocks_inter_turn = false,
      })
      tip_queue.enqueue({
        text = "blocking",
        duration = 2.0,
        dedupe_key = "blocking_tip",
        blocks_inter_turn = true,
      })

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), true, "blocking tip should gate inter-turn")
      _assert_eq(tip_queue.has_blocking_pending("choice"), false, "choice phase should ignore tip queue")
      _assert_eq(tip_queue.has_blocking_pending("landing"), false, "landing phase should ignore tip queue")

      timers[1].fn()

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), true, "active blocking tip should keep inter-turn gated")

      timers[2].fn()

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "inter-turn gate should clear after blocking tip drains")
    end)
  end)

  it("tip_queue_non_blocking_tip_never_gates_inter_turn", function()
    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function() end,
        scheduler = function()
          return true
        end,
      })

      tip_queue.enqueue({
        text = "diagnostic",
        duration = 2.0,
        dedupe_key = "diagnostic_tip",
        blocks_inter_turn = false,
      })

      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "non-blocking tip should not gate inter-turn")
    end)
  end)

  it("tip_queue_clear_cancels_stale_timeout_without_replaying_queue", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text)
          shown[#shown + 1] = text
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
      })

      tip_queue.enqueue({
        text = "first",
        duration = 3.0,
        dedupe_key = "first_tip",
        blocks_inter_turn = true,
      })
      tip_queue.enqueue({
        text = "second",
        duration = 2.0,
        dedupe_key = "second_tip",
        blocks_inter_turn = true,
      })

      _assert_eq(#shown, 1, "first tip should show immediately")
      _assert_eq(shown[1], "first", "first shown tip should be first")

      tip_queue.clear()
      timers[1].fn()

      _assert_eq(#shown, 1, "stale timeout should not replay cleared queue")
      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "clear should drop blocking gate")
    end)
  end)

  it("tip_queue_test_mode_drains_handled_scheduler_queue", function()
    local shown = {}
    local timers = {}

    _with_queue_runtime(function()
      tip_queue.configure_runtime({
        presenter = function(text)
          shown[#shown + 1] = text
        end,
        scheduler = function(delay, fn)
          timers[#timers + 1] = { delay = delay, fn = fn }
          return true
        end,
        test_mode = true,
      })

      tip_queue.enqueue({
        text = "first",
        duration = 3.0,
        dedupe_key = "first_tip",
      })
      tip_queue.enqueue({
        text = "second",
        duration = 2.0,
        dedupe_key = "second_tip",
      })

      _assert_eq(#shown, 2, "test mode should drain both handled tips without waiting for timer callbacks")
      _assert_eq(shown[1], "first", "first tip should still preserve FIFO order in test mode")
      _assert_eq(shown[2], "second", "second tip should drain immediately after the first tip")
      _assert_eq(#timers, 2, "test mode should still invoke the scheduler for each shown tip")
      _assert_eq(tip_queue.has_blocking_pending("inter_turn"), false, "test mode drain should leave no blocking tip behind")
    end)
  end)
end)
