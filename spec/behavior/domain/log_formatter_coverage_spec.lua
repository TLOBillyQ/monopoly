local log_formatter = require("src.foundation.log").formatter

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- stringify






-- format_entry




-- get_entries: linear (no count/head)



-- get_entries: circular buffer (with count/head)





-- get_entries_by_level





-- get_text



-- get_text_by_level

describe("domain log formatter coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("stringify returns empty string for no args", function()
    local result = log_formatter.stringify(1)
    _assert_eq(result, "", "no args beyond start should return empty string")
  end)

  it("stringify concatenates args from start", function()
    local result = log_formatter.stringify(1, "hello", "world")
    _assert_eq(result, "hello world", "should join args with space")
  end)

  it("stringify skips args before start_index", function()
    local result = log_formatter.stringify(2, "skip", "keep", "this")
    _assert_eq(result, "keep this", "should skip args before start_index")
  end)

  it("stringify converts non strings", function()
    local result = log_formatter.stringify(1, 42, true, nil)
    _assert_eq(result, "42 true nil", "should tostring each arg")
  end)

  it("stringify defaults to 1 when nil start", function()
    local result = log_formatter.stringify(nil, "a", "b")
    _assert_eq(result, "a b", "nil start_index should default to 1")
  end)

  it("format_entry with time_text", function()
    local entry = { time_text = "12:00", level = "INFO", text = "msg" }
    local result = log_formatter.format_entry(entry)
    _assert_eq(result, "12:00 [INFO] msg", "should include time_text")
  end)

  it("format_entry without time_text", function()
    local entry = { level = "WARN", text = "something" }
    local result = log_formatter.format_entry(entry)
    _assert_eq(result, "[WARN] something", "no time_text should omit it")
  end)

  it("format_entry defaults empty fields", function()
    local entry = {}
    local result = log_formatter.format_entry(entry)
    _assert_eq(result, "[] ", "missing fields should default to empty string")
  end)

  it("get_entries returns all when no count head", function()
    local state = { entries = { { level = "A" }, { level = "B" } } }
    local result = log_formatter.get_entries(state)
    _assert_eq(#result, 2, "should return all entries when no count/head")
  end)

  it("get_entries limits by max_lines", function()
    local state = { entries = { { level = "A" }, { level = "B" }, { level = "C" } } }
    local result = log_formatter.get_entries(state, 2)
    _assert_eq(#result, 2, "max_lines should limit result")
    _assert_eq(result[1].level, "B", "should take last N entries")
    _assert_eq(result[2].level, "C", "last entry should be last")
  end)

  it("get_entries empty when count zero", function()
    local state = { entries = { { level = "A" } }, entries_count = 0, entries_head = 1 }
    local result = log_formatter.get_entries(state)
    _assert_eq(#result, 0, "count=0 should return empty")
  end)

  it("get_entries circular buffer single", function()
    local state = {
      entries = { { level = "X" } },
      entries_count = 1,
      entries_head = 1,
    }
    local result = log_formatter.get_entries(state)
    _assert_eq(#result, 1, "circular buffer single entry")
    _assert_eq(result[1].level, "X", "should return entry at head")
  end)

  it("get_entries circular buffer wraps", function()
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
  end)

  it("get_entries nil entries uses empty default", function()
    local state = { entries_count = nil, entries_head = nil }
    local result = log_formatter.get_entries(state)
    _assert_eq(#result, 0, "nil entries should return empty")
  end)

  it("get_entries_by_level nil level returns all", function()
    local state = { entries = { { level = "A" }, { level = "B" } } }
    local result = log_formatter.get_entries_by_level(state, nil)
    _assert_eq(#result, 2, "nil level should return all entries")
  end)

  it("get_entries_by_level filters by level", function()
    local state = { entries = { { level = "INFO" }, { level = "WARN" }, { level = "INFO" } } }
    local result = log_formatter.get_entries_by_level(state, "INFO")
    _assert_eq(#result, 2, "should return only INFO entries")
  end)

  it("get_entries_by_level empty when no match", function()
    local state = { entries = { { level = "INFO" } } }
    local result = log_formatter.get_entries_by_level(state, "WARN")
    _assert_eq(#result, 0, "no match should return empty")
  end)

  it("get_entries_by_level respects max_lines", function()
    local state = { entries = { { level = "X" }, { level = "X" }, { level = "X" } } }
    local result = log_formatter.get_entries_by_level(state, "X", 2)
    _assert_eq(#result, 2, "max_lines should apply after filtering")
  end)

  it("get_text joins entries with newline", function()
    local state = {
      entries = { { level = "A", text = "msg1" }, { level = "B", text = "msg2" } },
    }
    local result = log_formatter.get_text(state)
    _assert_eq(result, "[A] msg1\n[B] msg2", "should join formatted entries with newline")
  end)

  it("get_text empty when no entries", function()
    local state = {}
    local result = log_formatter.get_text(state)
    _assert_eq(result, "", "empty entries should return empty string")
  end)

  it("get_text_by_level filters and formats", function()
    local state = {
      entries = { { level = "INFO", text = "a" }, { level = "WARN", text = "b" }, { level = "INFO", text = "c" } },
    }
    local result = log_formatter.get_text_by_level(state, "INFO")
    _assert_eq(result, "[INFO] a\n[INFO] c", "should filter by level and join")
  end)
end)
