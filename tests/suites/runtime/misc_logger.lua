local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local logger = require("src.core.utils.logger")
local tip_queue = require("src.core.utils.tip_queue")

local function _with_logger_capacity(capacity, fn)
  local original_capacity = logger.max_entries
  logger.max_entries = capacity
  logger.clear()
  local ok, err = pcall(fn)
  logger.clear()
  logger.max_entries = original_capacity
  if not ok then
    error(err)
  end
end

local function _with_tip_runtime(fn)
  tip_queue.clear()
  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
    test_mode = logger.is_test_mode(),
  })
  local ok, err = pcall(fn)
  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
    test_mode = logger.is_test_mode(),
  })
  tip_queue.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_only_writes_event_feed_without_showing_tip()
  local shown = {}

  logger.clear()
  _with_tip_runtime(function()
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
    })
    logger.event("log event message")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "log event message", 1, true) ~= nil, "event should still enter event feed")
    _assert_eq(#shown, 0, "event should no longer trigger tips")
  end)
  logger.clear()
end

local function _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip()
  local shown = {}

  logger.clear()
  _with_tip_runtime(function()
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
    })
    logger.event_no_tips("phase event message")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "phase event message", 1, true) ~= nil, "event_no_tips should still enter event feed")
    _assert_eq(#shown, 0, "event_no_tips should not trigger tips")
  end)
  logger.clear()
end

local function _test_logger_configure_game_time_uses_injected_clock()
  local shown = {}

  logger.clear()
  _with_tip_runtime(function()
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
    })
    logger.configure_game_time({
      get_timestamp = function()
        return 65
      end,
      get_hour = function()
        return 1
      end,
      get_minute = function()
        return 2
      end,
      get_second = function()
        return 3
      end,
    })
    logger.event("host runtime injected")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "01:02:03", 1, true) ~= nil, "logger should use injected game clock formatter")
    _assert_eq(#shown, 0, "logger runtime config should not reintroduce event tips")
  end)
  logger.reset_time_runtime()
  logger.clear()
end

local function _test_logger_event_collection_provider_drops_closed_action_log_events()
  local shown = {}

  logger.clear()
  _with_tip_runtime(function()
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
    })
    logger.set_event_collection_enabled_provider(function()
      return false
    end)

    logger.event("closed action log event")
    local text = logger.get_text_by_level("event")
    _assert_eq(text, "", "closed action log should not retain event feed entries")
    _assert_eq(#shown, 0, "closed action log should not emit tips anymore")
  end)
  logger.set_event_collection_enabled_provider(nil)
  logger.clear()
end

local function _test_logger_event_seq_only_tracks_event_feed_changes()
  logger.clear()

  local ok, err = pcall(function()
    local initial_seq = logger.get_event_seq()

    logger.info("info message")
    _assert_eq(logger.get_event_seq(), initial_seq, "info should not change event_seq")

    logger.warn("warn message")
    _assert_eq(logger.get_event_seq(), initial_seq, "warn should not change event_seq")

    logger.event("event message")
    local event_seq = logger.get_event_seq()
    assert(event_seq > initial_seq, "event should advance event_seq")

    logger.event_no_tips("event no tips message")
    local event_no_tips_seq = logger.get_event_seq()
    assert(event_no_tips_seq > event_seq, "event_no_tips should advance event_seq")

    logger.clear()
    assert(logger.get_event_seq() > event_no_tips_seq, "clear should advance event_seq for UI reset")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_replays_buffered_events()
  logger.clear()
  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  local ok, err = pcall(function()
    logger.event("first buffered event")
    logger.event("second buffered event")

    local text_before = logger.get_text_by_level("event")
    _assert_eq(text_before, "", "buffered events should not appear in feed before flush")

    local flushed = logger.flush_event_buffer(buffer)
    _assert_eq(flushed, true, "flush should return true when buffer has entries")

    local text_after = logger.get_text_by_level("event")
    assert(string.find(text_after, "first buffered event", 1, true) ~= nil, "flush should replay first buffered event")
    assert(string.find(text_after, "second buffered event", 1, true) ~= nil, "flush should replay second buffered event")
  end)

  logger.pop_event_buffer(buffer)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_skips_when_buffer_not_active()
  logger.clear()
  local buffer = { entries = {} }

  local ok, err = pcall(function()
    logger.event("event before buffer")
    local flushed = logger.flush_event_buffer(buffer)
    _assert_eq(flushed, false, "flush should return false when buffer is not active")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_no_tip_replay()
  logger.clear()
  local shown = {}
  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  _with_tip_runtime(function()
    tip_queue.configure_runtime({
      presenter = function(text, duration)
        shown[#shown + 1] = { text = text, duration = duration }
      end,
    })
    logger.event_no_tips("no tip event")
    logger.flush_event_buffer(buffer)

    local text = logger.get_text_by_level("event")
    assert(string.find(text, "no tip event", 1, true) ~= nil, "flush should replay no_tip event to feed, text=" .. tostring(text))
    _assert_eq(#shown, 0, "flush should not show tip for no_tip events")
  end)

  logger.pop_event_buffer(buffer)
  logger.clear()
end

local function _test_logger_flush_event_buffer_empty_buffer_returns_false()
  logger.clear()
  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  local ok, err = pcall(function()
    local flushed = logger.flush_event_buffer(buffer)
    _assert_eq(flushed, false, "flush should return false for empty buffer")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_flush_event_buffer_invalid_buffer_returns_false()
  logger.clear()

  local ok, err = pcall(function()
    _assert_eq(logger.flush_event_buffer(nil), false, "flush should return false for nil buffer")
    _assert_eq(logger.flush_event_buffer("string"), false, "flush should return false for string buffer")
    _assert_eq(logger.flush_event_buffer(123), false, "flush should return false for number buffer")
  end)

  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_set_test_mode_syncs_tip_queue_runtime()
  local shown = {}
  local timers = {}
  local original_test_mode = logger.is_test_mode()

  logger.clear()
  _with_tip_runtime(function()
    tip_queue.configure_runtime({
      presenter = function(text)
        shown[#shown + 1] = text
      end,
      scheduler = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
      test_mode = false,
    })

    logger.set_test_mode(false)
    tip_queue.enqueue({
      text = "non_test_mode_active",
      duration = 3.0,
      dedupe_key = "non_test_mode_active",
    })
    tip_queue.enqueue({
      text = "non_test_mode_pending",
      duration = 2.0,
      dedupe_key = "non_test_mode_pending",
    })

    _assert_eq(#shown, 1, "without test mode, handled scheduler should keep pending tip queued")
    _assert_eq(shown[1], "non_test_mode_active", "first queued tip should still show immediately")

    tip_queue.clear()
    shown = {}
    timers = {}

    logger.set_test_mode(true)
    tip_queue.enqueue({
      text = "test_mode_first",
      duration = 3.0,
      dedupe_key = "test_mode_first",
    })
    tip_queue.enqueue({
      text = "test_mode_second",
      duration = 2.0,
      dedupe_key = "test_mode_second",
    })

    _assert_eq(#shown, 2, "logger.set_test_mode should propagate to tip_queue and drain handled tips")
    _assert_eq(shown[1], "test_mode_first", "first tip should preserve FIFO order after logger sync")
    _assert_eq(shown[2], "test_mode_second", "second tip should drain immediately after logger sync")
    _assert_eq(#timers, 2, "scheduler should still be called for both drained tips")

    logger.set_test_mode(original_test_mode)
  end)
  logger.set_test_mode(original_test_mode)
  logger.clear()
end

local function _test_logger_ring_buffer_push_overflow_wraps()
  _with_logger_capacity(3, function()
    logger.info("q1")
    logger.info("q2")
    logger.info("q3")
    logger.info("q4")

    local entries = logger.get_entries()
    _assert_eq(#entries, 3, "overflow should keep capacity-sized history")
    _assert_eq(entries[1].text, "q2", "oldest entry should drop first when queue overflows")
    _assert_eq(entries[2].text, "q3", "middle entry should preserve FIFO order")
    _assert_eq(entries[3].text, "q4", "newest entry should be appended after wrap")
  end)
end

local function _test_logger_ring_buffer_capacity_limit_respected()
  _with_logger_capacity(2, function()
    logger.warn("c1")
    logger.warn("c2")
    logger.warn("c3")
    logger.warn("c4")

    local entries = logger.get_entries()
    _assert_eq(#entries, 2, "queue should never exceed configured capacity")
    _assert_eq(entries[1].text, "c3", "queue should keep the latest N entries")
    _assert_eq(entries[2].text, "c4", "queue should keep newest entry at tail")
  end)
end

local function _test_logger_ring_buffer_iteration_order_oldest_first()
  _with_logger_capacity(3, function()
    logger.event("o1")
    logger.event("o2")
    logger.event("o3")
    logger.event("o4")
    logger.event("o5")

    local entries = logger.get_entries()
    _assert_eq(#entries, 3, "wrapped queue should still return full capacity entries")
    _assert_eq(entries[1].text, "o3", "iteration should start from oldest retained entry")
    _assert_eq(entries[2].text, "o4", "iteration should preserve chronological order")
    _assert_eq(entries[3].text, "o5", "iteration should end at newest retained entry")
  end)
end

return {
  { name = "logger_event_only_writes_event_feed_without_showing_tip", run = _test_logger_event_only_writes_event_feed_without_showing_tip },
  { name = "logger_event_no_tips_stays_in_event_feed_without_showing_tip", run = _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip },
  { name = "logger_configure_game_time_uses_injected_clock", run = _test_logger_configure_game_time_uses_injected_clock },
  { name = "logger_event_collection_provider_drops_closed_action_log_events", run = _test_logger_event_collection_provider_drops_closed_action_log_events },
  { name = "logger_event_seq_only_tracks_event_feed_changes", run = _test_logger_event_seq_only_tracks_event_feed_changes },
  { name = "logger_flush_event_buffer_replays_buffered_events", run = _test_logger_flush_event_buffer_replays_buffered_events },
  { name = "logger_flush_event_buffer_skips_when_buffer_not_active", run = _test_logger_flush_event_buffer_skips_when_buffer_not_active },
  { name = "logger_flush_event_buffer_no_tip_replay", run = _test_logger_flush_event_buffer_no_tip_replay },
  { name = "logger_flush_event_buffer_empty_buffer_returns_false", run = _test_logger_flush_event_buffer_empty_buffer_returns_false },
  { name = "logger_flush_event_buffer_invalid_buffer_returns_false", run = _test_logger_flush_event_buffer_invalid_buffer_returns_false },
  { name = "logger_set_test_mode_syncs_tip_queue_runtime", run = _test_logger_set_test_mode_syncs_tip_queue_runtime },
  { name = "logger_ring_buffer_push_overflow_wraps", run = _test_logger_ring_buffer_push_overflow_wraps },
  { name = "logger_ring_buffer_capacity_limit_respected", run = _test_logger_ring_buffer_capacity_limit_respected },
  { name = "logger_ring_buffer_iteration_order_oldest_first", run = _test_logger_ring_buffer_iteration_order_oldest_first },
}
