local logger = require("src.core.utils.logger")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- set_event_collection_enabled_provider

local function test_set_event_collection_enabled_provider_nil_clears()
  local saved = logger.event_collection_enabled_provider
  logger.set_event_collection_enabled_provider(nil)
  _assert_eq(logger.event_collection_enabled_provider, nil,
    "nil provider should clear event_collection_enabled_provider")
  logger.event_collection_enabled_provider = saved
end

local function test_set_event_collection_enabled_provider_function_sets()
  local saved = logger.event_collection_enabled_provider
  local fn = function() return true end
  logger.set_event_collection_enabled_provider(fn)
  _assert_eq(logger.event_collection_enabled_provider, fn, "provider should be set")
  logger.event_collection_enabled_provider = saved
end

local function test_set_event_collection_enabled_provider_invalid_type_asserts()
  local ok = pcall(function()
    logger.set_event_collection_enabled_provider("not_a_function")
  end)
  _assert_eq(ok, false, "non-function provider should assert")
end

-- set_anim_debug_enabled_provider

local function test_set_anim_debug_enabled_provider_nil_clears()
  local saved = logger.anim_debug_enabled_provider
  logger.set_anim_debug_enabled_provider(nil)
  _assert_eq(logger.anim_debug_enabled_provider, nil,
    "nil provider should clear anim_debug_enabled_provider")
  logger.anim_debug_enabled_provider = saved
end

local function test_set_anim_debug_enabled_provider_function_sets()
  local saved = logger.anim_debug_enabled_provider
  local fn = function() return false end
  logger.set_anim_debug_enabled_provider(fn)
  _assert_eq(logger.anim_debug_enabled_provider, fn, "provider should be set")
  logger.anim_debug_enabled_provider = saved
end

local function test_set_anim_debug_enabled_provider_invalid_type_asserts()
  local ok = pcall(function()
    logger.set_anim_debug_enabled_provider(42)
  end)
  _assert_eq(ok, false, "non-function provider should assert")
end

-- is_anim_debug_enabled

local function test_is_anim_debug_enabled_no_provider_returns_false()
  local saved = logger.anim_debug_enabled_provider
  logger.anim_debug_enabled_provider = nil
  _assert_eq(logger.is_anim_debug_enabled(), false, "no provider should return false")
  logger.anim_debug_enabled_provider = saved
end

local function test_is_anim_debug_enabled_provider_returns_true()
  local saved = logger.anim_debug_enabled_provider
  logger.set_anim_debug_enabled_provider(function() return true end)
  _assert_eq(logger.is_anim_debug_enabled(), true, "provider returning true should return true")
  logger.anim_debug_enabled_provider = saved
end

local function test_is_anim_debug_enabled_provider_returns_false()
  local saved = logger.anim_debug_enabled_provider
  logger.set_anim_debug_enabled_provider(function() return false end)
  _assert_eq(logger.is_anim_debug_enabled(), false, "provider returning false should return false")
  logger.anim_debug_enabled_provider = saved
end

local function test_is_anim_debug_enabled_provider_throws_returns_false()
  local saved = logger.anim_debug_enabled_provider
  logger.set_anim_debug_enabled_provider(function() error("provider error") end)
  _assert_eq(logger.is_anim_debug_enabled(), false, "throwing provider should return false")
  logger.anim_debug_enabled_provider = saved
end

-- configure_game_time

local function test_configure_game_time_sets_timestamp_and_formatter()
  local saved_ts = logger.timestamp_provider
  local saved_fmt = logger.time_formatter
  local game_api = {
    get_timestamp = function() return 1234 end,
    get_hour = function() return 9 end,
    get_minute = function() return 5 end,
    get_second = function() return 3 end,
  }
  logger.configure_game_time(game_api)
  _assert_eq(logger.timestamp_provider(), 1234, "timestamp_provider should delegate to game_api")
  local formatted = logger.time_formatter(1234)
  _assert_eq(formatted, "09:05:03", "time_formatter should format with leading zeros")
  logger.timestamp_provider = saved_ts
  logger.time_formatter = saved_fmt
end

local function test_configure_game_time_no_leading_zero_when_not_needed()
  local saved_ts = logger.timestamp_provider
  local saved_fmt = logger.time_formatter
  local game_api = {
    get_timestamp = function() return 0 end,
    get_hour = function() return 14 end,
    get_minute = function() return 30 end,
    get_second = function() return 45 end,
  }
  logger.configure_game_time(game_api)
  local formatted = logger.time_formatter(0)
  _assert_eq(formatted, "14:30:45", "no leading zero for values >= 10")
  logger.timestamp_provider = saved_ts
  logger.time_formatter = saved_fmt
end

-- simple setter tests

local function test_set_file_io_enabled_true()
  local saved = logger.enable_file_io
  logger.set_file_io_enabled(true)
  _assert_eq(logger.enable_file_io, true, "should set enable_file_io to true")
  logger.enable_file_io = saved
end

local function test_set_file_io_enabled_false()
  local saved = logger.enable_file_io
  logger.set_file_io_enabled(false)
  _assert_eq(logger.enable_file_io, false, "should set enable_file_io to false")
  logger.enable_file_io = saved
end

local function test_set_info_per_turn_limit()
  local saved = logger.info_per_turn_limit
  logger.set_info_per_turn_limit(5)
  _assert_eq(logger.info_per_turn_limit, 5, "should set info_per_turn_limit")
  logger.info_per_turn_limit = saved
end

local function test_set_info_turn_provider()
  local saved = logger.info_turn_provider
  local fn = function() return 10 end
  logger.set_info_turn_provider(fn)
  _assert_eq(logger.info_turn_provider, fn, "should set info_turn_provider")
  logger.info_turn_provider = saved
end

local function test_set_ui_sink()
  local saved = logger.ui_sink
  local sink = { push = function() end }
  logger.set_ui_sink(sink)
  _assert_eq(logger.ui_sink, sink, "should set ui_sink")
  logger.ui_sink = saved
end

-- event buffer

local function test_push_and_pop_event_buffer()
  local saved_stack = logger.event_buffer_stack
  logger.event_buffer_stack = {}
  local buf = { events = {} }
  logger.push_event_buffer(buf)
  assert(#logger.event_buffer_stack == 1, "buffer should be pushed")
  logger.pop_event_buffer(buf)
  assert(#logger.event_buffer_stack == 0, "buffer should be popped")
  logger.event_buffer_stack = saved_stack
end

local function test_flush_event_buffer_pops_buffer()
  local saved_stack = logger.event_buffer_stack
  logger.event_buffer_stack = {}
  local buf = {}
  logger.push_event_buffer(buf)
  assert(#logger.event_buffer_stack == 1, "buffer should be pushed")
  logger.flush_event_buffer(buf)
  assert(#logger.event_buffer_stack == 0, "buffer should be removed after flush")
  logger.event_buffer_stack = saved_stack
end

-- event_no_tips

local function test_event_no_tips_does_not_error()
  local ok = pcall(function()
    logger.event_no_tips("no_tip_event")
  end)
  _assert_eq(ok, true, "event_no_tips should not throw")
end

-- reset_time_runtime

local function test_reset_time_runtime_restores_defaults()
  local saved_ts = logger.timestamp_provider
  local saved_fmt = logger.time_formatter
  logger.timestamp_provider = function() return 999 end
  logger.time_formatter = function(_) return "custom" end
  logger.reset_time_runtime()
  _assert_eq(logger.timestamp_provider(), 0, "reset should restore zero timestamp")
  _assert_eq(logger.time_formatter(0), "0", "reset should restore tostring formatter")
  logger.timestamp_provider = saved_ts
  logger.time_formatter = saved_fmt
end

-- set_test_mode / is_test_mode

local function test_set_and_is_test_mode()
  local saved = logger.test_mode
  logger.set_test_mode(true)
  _assert_eq(logger.is_test_mode(), true, "is_test_mode should return true after set true")
  logger.set_test_mode(false)
  _assert_eq(logger.is_test_mode(), false, "is_test_mode should return false after set false")
  logger.test_mode = saved
end

-- info / warn / event / info_unlimited

local function test_info_does_not_error()
  local ok = pcall(function() logger.info("test info message") end)
  _assert_eq(ok, true, "logger.info should not throw")
end

local function test_warn_does_not_error()
  local ok = pcall(function() logger.warn("test warn message") end)
  _assert_eq(ok, true, "logger.warn should not throw")
end

local function test_event_does_not_error()
  local ok = pcall(function() logger.event("test event message") end)
  _assert_eq(ok, true, "logger.event should not throw")
end

local function test_info_unlimited_does_not_error()
  local ok = pcall(function() logger.info_unlimited("test unlimited") end)
  _assert_eq(ok, true, "logger.info_unlimited should not throw")
end

-- get_seq / get_event_seq

local function test_get_seq_returns_number()
  local seq = logger.get_seq()
  assert(type(seq) == "number", "get_seq should return a number")
end

local function test_get_event_seq_returns_number()
  local seq = logger.get_event_seq()
  assert(type(seq) == "number", "get_event_seq should return a number")
end

-- clear increments seq

local function test_clear_increments_seq()
  local before = logger.get_seq()
  logger.clear()
  _assert_eq(logger.get_seq(), before + 1, "clear should increment seq")
end

-- get_entries / get_text delegates

local function test_get_entries_returns_table()
  local entries = logger.get_entries(5)
  assert(type(entries) == "table", "get_entries should return a table")
end

local function test_get_entries_by_level_returns_table()
  local entries = logger.get_entries_by_level("info", 5)
  assert(type(entries) == "table", "get_entries_by_level should return a table")
end

local function test_get_text_returns_string()
  local text = logger.get_text(5)
  assert(type(text) == "string", "get_text should return a string")
end

local function test_get_text_by_level_returns_string()
  local text = logger.get_text_by_level("event", 5)
  assert(type(text) == "string", "get_text_by_level should return a string")
end

return {
  name = "domain logger coverage",
  tests = {
    { name = "set_event_collection_enabled_provider nil clears", run = test_set_event_collection_enabled_provider_nil_clears },
    { name = "set_event_collection_enabled_provider function sets", run = test_set_event_collection_enabled_provider_function_sets },
    { name = "set_event_collection_enabled_provider invalid type asserts", run = test_set_event_collection_enabled_provider_invalid_type_asserts },
    { name = "set_anim_debug_enabled_provider nil clears", run = test_set_anim_debug_enabled_provider_nil_clears },
    { name = "set_anim_debug_enabled_provider function sets", run = test_set_anim_debug_enabled_provider_function_sets },
    { name = "set_anim_debug_enabled_provider invalid type asserts", run = test_set_anim_debug_enabled_provider_invalid_type_asserts },
    { name = "is_anim_debug_enabled no provider returns false", run = test_is_anim_debug_enabled_no_provider_returns_false },
    { name = "is_anim_debug_enabled provider returns true", run = test_is_anim_debug_enabled_provider_returns_true },
    { name = "is_anim_debug_enabled provider returns false", run = test_is_anim_debug_enabled_provider_returns_false },
    { name = "is_anim_debug_enabled provider throws returns false", run = test_is_anim_debug_enabled_provider_throws_returns_false },
    { name = "configure_game_time sets timestamp and formatter", run = test_configure_game_time_sets_timestamp_and_formatter },
    { name = "configure_game_time no leading zero when not needed", run = test_configure_game_time_no_leading_zero_when_not_needed },
    { name = "set_file_io_enabled true", run = test_set_file_io_enabled_true },
    { name = "set_file_io_enabled false", run = test_set_file_io_enabled_false },
    { name = "set_info_per_turn_limit", run = test_set_info_per_turn_limit },
    { name = "set_info_turn_provider", run = test_set_info_turn_provider },
    { name = "set_ui_sink", run = test_set_ui_sink },
    { name = "push and pop event buffer", run = test_push_and_pop_event_buffer },
    { name = "flush event buffer pops buffer", run = test_flush_event_buffer_pops_buffer },
    { name = "event_no_tips does not error", run = test_event_no_tips_does_not_error },
    { name = "reset_time_runtime restores defaults", run = test_reset_time_runtime_restores_defaults },
    { name = "set_test_mode and is_test_mode", run = test_set_and_is_test_mode },
    { name = "info does not error", run = test_info_does_not_error },
    { name = "warn does not error", run = test_warn_does_not_error },
    { name = "event does not error", run = test_event_does_not_error },
    { name = "info_unlimited does not error", run = test_info_unlimited_does_not_error },
    { name = "get_seq returns number", run = test_get_seq_returns_number },
    { name = "get_event_seq returns number", run = test_get_event_seq_returns_number },
    { name = "clear increments seq", run = test_clear_increments_seq },
    { name = "get_entries returns table", run = test_get_entries_returns_table },
    { name = "get_entries_by_level returns table", run = test_get_entries_by_level_returns_table },
    { name = "get_text returns string", run = test_get_text_returns_string },
    { name = "get_text_by_level returns string", run = test_get_text_by_level_returns_string },
  },
}
