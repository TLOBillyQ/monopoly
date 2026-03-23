local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local logger = require("src.core.utils.logger")

local function _test_logger_event_only_writes_event_feed_without_showing_tip()
  local shown = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  local ok, err = pcall(function()
    logger.event("log event message")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "log event message", 1, true) ~= nil, "event should still enter event feed")
    _assert_eq(#shown, 0, "event should no longer trigger tips")
  end)
  logger.set_tip_presenter(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip()
  local shown = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  local ok, err = pcall(function()
    logger.event_no_tips("phase event message")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "phase event message", 1, true) ~= nil, "event_no_tips should still enter event feed")
    _assert_eq(#shown, 0, "event_no_tips should not trigger tips")
  end)
  logger.set_tip_presenter(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_configure_host_runtime_uses_injected_hooks()
  local shown = {}

  logger.clear()
  logger.configure_host_runtime({
    game_api = {
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
    },
    tip_presenter = function(text, duration)
      shown[#shown + 1] = { text = text, duration = duration }
    end,
  })

  local ok, err = pcall(function()
    logger.event("host runtime injected")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "01:02:03", 1, true) ~= nil, "logger should use injected game clock formatter")
    _assert_eq(#shown, 0, "logger runtime config should not reintroduce event tips")
  end)

  logger.set_tip_presenter(nil)
  logger.set_timestamp_provider(function()
    return 0
  end)
  logger.set_time_formatter(function(timestamp)
    return tostring(timestamp)
  end)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_collection_provider_drops_closed_action_log_events()
  local shown = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  logger.set_event_collection_enabled_provider(function()
    return false
  end)

  local ok, err = pcall(function()
    logger.event("closed action log event")
    local text = logger.get_text_by_level("event")
    _assert_eq(text, "", "closed action log should not retain event feed entries")
    _assert_eq(#shown, 0, "closed action log should not emit tips anymore")
  end)

  logger.set_tip_presenter(nil)
  logger.set_event_collection_enabled_provider(nil)
  logger.clear()
  if not ok then
    error(err)
  end
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
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)

  local buffer = { entries = {} }
  logger.push_event_buffer(buffer)

  local ok, err = pcall(function()
    logger.event_no_tips("no tip event")
    logger.flush_event_buffer(buffer)

    local text = logger.get_text_by_level("event")
    assert(string.find(text, "no tip event", 1, true) ~= nil, "flush should replay no_tip event to feed, text=" .. tostring(text))
    _assert_eq(#shown, 0, "flush should not show tip for no_tip events")
  end)

  logger.pop_event_buffer(buffer)
  logger.set_tip_presenter(nil)
  logger.clear()
  if not ok then
    error(err)
  end
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

return {
  { name = "logger_event_only_writes_event_feed_without_showing_tip", run = _test_logger_event_only_writes_event_feed_without_showing_tip },
  { name = "logger_event_no_tips_stays_in_event_feed_without_showing_tip", run = _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip },
  { name = "logger_configure_host_runtime_uses_injected_hooks", run = _test_logger_configure_host_runtime_uses_injected_hooks },
  { name = "logger_event_collection_provider_drops_closed_action_log_events", run = _test_logger_event_collection_provider_drops_closed_action_log_events },
  { name = "logger_event_seq_only_tracks_event_feed_changes", run = _test_logger_event_seq_only_tracks_event_feed_changes },
  { name = "logger_flush_event_buffer_replays_buffered_events", run = _test_logger_flush_event_buffer_replays_buffered_events },
  { name = "logger_flush_event_buffer_skips_when_buffer_not_active", run = _test_logger_flush_event_buffer_skips_when_buffer_not_active },
  { name = "logger_flush_event_buffer_no_tip_replay", run = _test_logger_flush_event_buffer_no_tip_replay },
  { name = "logger_flush_event_buffer_empty_buffer_returns_false", run = _test_logger_flush_event_buffer_empty_buffer_returns_false },
  { name = "logger_flush_event_buffer_invalid_buffer_returns_false", run = _test_logger_flush_event_buffer_invalid_buffer_returns_false },
}
