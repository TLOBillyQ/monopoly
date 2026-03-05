local support = require("TestSupport")
local _assert_eq = support.assert_eq
local number_utils = support.number_utils
local _with_patches = support.with_patches
local logger = require("src.core.Logger")

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
  _with_patches({
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
      },
    },
    {
      key = "SetTimeOut",
      value = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
    },
  }, function()
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
  logger.clear()
end

local function _test_logger_event_tip_defers_until_current_tip_finishes()
  local shown = {}
  local timers = {}

  logger.clear()
  _with_patches({
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
      },
    },
    {
      key = "SetTimeOut",
      value = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
        return true
      end,
    },
  }, function()
    logger.show_tip("market_failed", 3.0)
    logger.event("log event message")

    _assert_eq(#shown, 1, "log event tip should defer while market tip is active")
    _assert_eq(shown[1].text, "market_failed", "first tip should be market_failed")

    timers[1].fn()

    _assert_eq(#shown, 2, "log event tip should show after market tip")
    _assert_eq(shown[2].text, "log event message", "second tip should be log event")
  end)
  logger.clear()
end

local function _test_logger_show_tip_respects_global_mute_switch()
  local shown = {}
  logger.clear()
  _with_patches({
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text, duration)
          shown[#shown + 1] = { text = text, duration = duration }
        end,
      },
    },
    {
      key = "EGGY_MUTE_LUA_TIPS",
      value = true,
    },
  }, function()
    local ok = logger.show_tip("should_be_muted", 2.0, { source = "test" })
    _assert_eq(ok, true, "show_tip should keep success semantics when muted")
  end)
  _assert_eq(#shown, 0, "muted Lua tips should not call GlobalAPI.show_tips")
  logger.clear()
end

return {
  name = "misc",
  tests = {
    { name = "number_utils_to_integer", run = _test_number_utils_to_integer },
    { name = "number_utils_to_integer_fallback_from_tostring", run = _test_number_utils_to_integer_fallback_from_tostring },
    { name = "number_utils_to_integer_fallback_rejects_non_integer_text", run = _test_number_utils_to_integer_fallback_rejects_non_integer_text },
    { name = "logger_show_tip_uses_fifo_queue_without_override", run = _test_logger_show_tip_uses_fifo_queue_without_override },
    { name = "logger_event_tip_defers_until_current_tip_finishes", run = _test_logger_event_tip_defers_until_current_tip_finishes },
    { name = "logger_show_tip_respects_global_mute_switch", run = _test_logger_show_tip_respects_global_mute_switch },
  },
}
