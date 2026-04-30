local log_formatter = require("src.foundation.log.formatter")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- stringify

local function test_stringify_returns_empty_string_for_no_args()
  local result = log_formatter.stringify(1)
  _assert_eq(result, "", "no args beyond start should return empty string")
end

local function test_stringify_concatenates_args_from_start()
  local result = log_formatter.stringify(1, "hello", "world")
  _assert_eq(result, "hello world", "should join args with space")
end

local function test_stringify_skips_args_before_start_index()
  local result = log_formatter.stringify(2, "skip", "keep", "this")
  _assert_eq(result, "keep this", "should skip args before start_index")
end

local function test_stringify_converts_non_strings()
  local result = log_formatter.stringify(1, 42, true, nil)
  _assert_eq(result, "42 true nil", "should tostring each arg")
end

local function test_stringify_defaults_to_1_when_nil_start()
  local result = log_formatter.stringify(nil, "a", "b")
  _assert_eq(result, "a b", "nil start_index should default to 1")
end

-- format_entry

local function test_format_entry_with_time_text()
  local entry = { time_text = "12:00", level = "INFO", text = "msg" }
  local result = log_formatter.format_entry(entry)
  _assert_eq(result, "12:00 [INFO] msg", "should include time_text")
end

local function test_format_entry_without_time_text()
  local entry = { level = "WARN", text = "something" }
  local result = log_formatter.format_entry(entry)
  _assert_eq(result, "[WARN] something", "no time_text should omit it")
end

local function test_format_entry_defaults_empty_fields()
  local entry = {}
  local result = log_formatter.format_entry(entry)
  _assert_eq(result, "[] ", "missing fields should default to empty string")
end

-- get_entries: linear (no count/head)

local function test_get_entries_returns_all_when_no_count_head()
  local state = { entries = { { level = "A" }, { level = "B" } } }
  local result = log_formatter.get_entries(state)
  _assert_eq(#result, 2, "should return all entries when no count/head")
end

local function test_get_entries_limits_by_max_lines()
  local state = { entries = { { level = "A" }, { level = "B" }, { level = "C" } } }
  local result = log_formatter.get_entries(state, 2)
  _assert_eq(#result, 2, "max_lines should limit result")
  _assert_eq(result[1].level, "B", "should take last N entries")
  _assert_eq(result[2].level, "C", "last entry should be last")
end

-- get_entries: circular buffer (with count/head)

local function test_get_entries_empty_when_count_zero()
  local state = { entries = { { level = "A" } }, entries_count = 0, entries_head = 1 }
  local result = log_formatter.get_entries(state)
  _assert_eq(#result, 0, "count=0 should return empty")
end

local function test_get_entries_circular_buffer_single()
  local state = {
    entries = { { level = "X" } },
    entries_count = 1,
    entries_head = 1,
  }
  local result = log_formatter.get_entries(state)
  _assert_eq(#result, 1, "circular buffer single entry")
  _assert_eq(result[1].level, "X", "should return entry at head")
end

local function test_get_entries_circular_buffer_wraps()
  -- 3-slot buffer, head=2, count=3: order is slots 2,3,1
  local state = {
    entries = { { level = "C" }, { level = "A" }, { level = "B" } },
    entries_count = 3,
    entries_head = 2,
  }
  local result = log_formatter.get_entries(state)
  _assert_eq(#result, 3, "circular buffer should return count entries")
  _assert_eq(result[1].level, "A", "first should be at head (slot 2)")
  _assert_eq(result[2].level, "B", "second should be slot 3")
  _assert_eq(result[3].level, "C", "third should wrap to slot 1")
end

local function test_get_entries_nil_entries_uses_empty_default()
  local state = { entries_count = nil, entries_head = nil }
  local result = log_formatter.get_entries(state)
  _assert_eq(#result, 0, "nil entries should return empty")
end

-- get_entries_by_level

local function test_get_entries_by_level_nil_level_returns_all()
  local state = { entries = { { level = "A" }, { level = "B" } } }
  local result = log_formatter.get_entries_by_level(state, nil)
  _assert_eq(#result, 2, "nil level should return all entries")
end

local function test_get_entries_by_level_filters_by_level()
  local state = { entries = { { level = "INFO" }, { level = "WARN" }, { level = "INFO" } } }
  local result = log_formatter.get_entries_by_level(state, "INFO")
  _assert_eq(#result, 2, "should return only INFO entries")
end

local function test_get_entries_by_level_empty_when_no_match()
  local state = { entries = { { level = "INFO" } } }
  local result = log_formatter.get_entries_by_level(state, "WARN")
  _assert_eq(#result, 0, "no match should return empty")
end

local function test_get_entries_by_level_respects_max_lines()
  local state = { entries = { { level = "X" }, { level = "X" }, { level = "X" } } }
  local result = log_formatter.get_entries_by_level(state, "X", 2)
  _assert_eq(#result, 2, "max_lines should apply after filtering")
end

-- get_text

local function test_get_text_joins_entries_with_newline()
  local state = {
    entries = { { level = "A", text = "msg1" }, { level = "B", text = "msg2" } },
  }
  local result = log_formatter.get_text(state)
  _assert_eq(result, "[A] msg1\n[B] msg2", "should join formatted entries with newline")
end

local function test_get_text_empty_when_no_entries()
  local state = {}
  local result = log_formatter.get_text(state)
  _assert_eq(result, "", "empty entries should return empty string")
end

-- get_text_by_level

local function test_get_text_by_level_filters_and_formats()
  local state = {
    entries = { { level = "INFO", text = "a" }, { level = "WARN", text = "b" }, { level = "INFO", text = "c" } },
  }
  local result = log_formatter.get_text_by_level(state, "INFO")
  _assert_eq(result, "[INFO] a\n[INFO] c", "should filter by level and join")
end

return {
  name = "domain log formatter coverage",
  tests = {
    { name = "stringify returns empty string for no args", run = test_stringify_returns_empty_string_for_no_args },
    { name = "stringify concatenates args from start", run = test_stringify_concatenates_args_from_start },
    { name = "stringify skips args before start_index", run = test_stringify_skips_args_before_start_index },
    { name = "stringify converts non strings", run = test_stringify_converts_non_strings },
    { name = "stringify defaults to 1 when nil start", run = test_stringify_defaults_to_1_when_nil_start },
    { name = "format_entry with time_text", run = test_format_entry_with_time_text },
    { name = "format_entry without time_text", run = test_format_entry_without_time_text },
    { name = "format_entry defaults empty fields", run = test_format_entry_defaults_empty_fields },
    { name = "get_entries returns all when no count head", run = test_get_entries_returns_all_when_no_count_head },
    { name = "get_entries limits by max_lines", run = test_get_entries_limits_by_max_lines },
    { name = "get_entries empty when count zero", run = test_get_entries_empty_when_count_zero },
    { name = "get_entries circular buffer single", run = test_get_entries_circular_buffer_single },
    { name = "get_entries circular buffer wraps", run = test_get_entries_circular_buffer_wraps },
    { name = "get_entries nil entries uses empty default", run = test_get_entries_nil_entries_uses_empty_default },
    { name = "get_entries_by_level nil level returns all", run = test_get_entries_by_level_nil_level_returns_all },
    { name = "get_entries_by_level filters by level", run = test_get_entries_by_level_filters_by_level },
    { name = "get_entries_by_level empty when no match", run = test_get_entries_by_level_empty_when_no_match },
    { name = "get_entries_by_level respects max_lines", run = test_get_entries_by_level_respects_max_lines },
    { name = "get_text joins entries with newline", run = test_get_text_joins_entries_with_newline },
    { name = "get_text empty when no entries", run = test_get_text_empty_when_no_entries },
    { name = "get_text_by_level filters and formats", run = test_get_text_by_level_filters_and_formats },
  },
}
