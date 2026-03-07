local support = require("TestSupport")
local _assert_eq = support.assert_eq
local number_utils = support.number_utils
local logger = require("src.core.utils.logger")

local function _test_number_utils_to_integer()
  _assert_eq(number_utils.to_integer("12"), 12, "string integer should parse")
  _assert_eq(number_utils.to_integer("-7"), -7, "negative string integer should parse")
  _assert_eq(number_utils.to_integer("12.3"), nil, "float string should be rejected")
end

local function _test_number_utils_to_integer_fallback_from_tostring()
  local wrapped = setmetatable({}, {
    __tostring = function()
      return "5"
    end,
  })
  _assert_eq(number_utils.to_integer(wrapped), 5, "non-numeric value should parse from tostring fallback")
end

local function _test_number_utils_to_integer_fallback_rejects_non_integer_text()
  local wrapped = setmetatable({}, {
    __tostring = function()
      return "abc"
    end,
  })
  _assert_eq(number_utils.to_integer(wrapped), nil, "non-integer tostring fallback should be rejected")
end

local function _test_logger_show_tip_uses_fifo_queue_without_override()
  local shown = {}
  local timers = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  logger.set_scheduler(function(delay, fn)
    timers[#timers + 1] = { delay = delay, fn = fn }
    return true
  end)
  local ok, err = pcall(function()
    logger.show_tip("A", 3.0)
    logger.show_tip("B", 2.0)

    _assert_eq(#shown, 1, "second tip should not override active tip")
    _assert_eq(shown[1].text, "A", "first shown tip should be A")
    _assert_eq(#timers, 1, "first tip should schedule one release timer")
    _assert_eq(timers[1].delay, 3.0, "first tip release timer should match duration")

    timers[1].fn()

    _assert_eq(#shown, 2, "second tip should show after first tip release")
    _assert_eq(shown[2].text, "B", "second shown tip should be B")
    _assert_eq(#timers, 2, "second tip should schedule another release timer")
    _assert_eq(timers[2].delay, 2.0, "second tip release timer should match duration")
  end)
  logger.set_tip_presenter(nil)
  logger.set_scheduler(nil)
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_logger_event_tip_defers_until_current_tip_finishes()
  local shown = {}
  local timers = {}

  logger.clear()
  logger.set_tip_presenter(function(text, duration)
    shown[#shown + 1] = { text = text, duration = duration }
  end)
  logger.set_scheduler(function(delay, fn)
    timers[#timers + 1] = { delay = delay, fn = fn }
    return true
  end)
  local ok, err = pcall(function()
    logger.show_tip("market_failed", 3.0)
    logger.event("log event message")

    _assert_eq(#shown, 1, "log event tip should defer while market tip is active")
    _assert_eq(shown[1].text, "market_failed", "first tip should be market_failed")

    timers[1].fn()

    _assert_eq(#shown, 2, "log event tip should show after market tip")
    _assert_eq(shown[2].text, "log event message", "second tip should be log event")
  end)
  logger.set_tip_presenter(nil)
  logger.set_scheduler(nil)
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
  local timers = {}

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
    scheduler = function(delay, fn)
      timers[#timers + 1] = { delay = delay, fn = fn }
      return true
    end,
  })

  local ok, err = pcall(function()
    logger.event("host runtime injected")
    local text = logger.get_text_by_level("event")
    assert(string.find(text, "01:02:03", 1, true) ~= nil, "logger should use injected game clock formatter")
    _assert_eq(#shown, 1, "logger should use injected tip presenter")
    _assert_eq(shown[1].text, "host runtime injected", "injected tip presenter should receive event text")
    _assert_eq(#timers, 1, "logger should use injected scheduler for tip release")
  end)

  logger.set_tip_presenter(nil)
  logger.set_scheduler(nil)
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

return {
  name = "misc",
  tests = {
    { name = "number_utils_to_integer", run = _test_number_utils_to_integer },
    { name = "number_utils_to_integer_fallback_from_tostring", run = _test_number_utils_to_integer_fallback_from_tostring },
    { name = "number_utils_to_integer_fallback_rejects_non_integer_text", run = _test_number_utils_to_integer_fallback_rejects_non_integer_text },
    { name = "logger_show_tip_uses_fifo_queue_without_override", run = _test_logger_show_tip_uses_fifo_queue_without_override },
    { name = "logger_event_tip_defers_until_current_tip_finishes", run = _test_logger_event_tip_defers_until_current_tip_finishes },
    { name = "logger_event_no_tips_stays_in_event_feed_without_showing_tip", run = _test_logger_event_no_tips_stays_in_event_feed_without_showing_tip },
    { name = "logger_configure_host_runtime_uses_injected_hooks", run = _test_logger_configure_host_runtime_uses_injected_hooks },
  },
}
