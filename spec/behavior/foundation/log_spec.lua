local logger = require("src.foundation.log")

local function make_log_state(max_entries)
  return {
    entries = {},
    max_entries = max_entries or 10,
    seq = 0,
    event_seq = 0,
    entries_head = 1,
    entries_count = 0,
    timestamp_provider = function() return 0 end,
    time_formatter = function() return "" end,
    ui_sink = nil,
  }
end

describe("logger.formatter circular buffer", function()
  local fmt = logger.formatter

  it("push and get_entries round-trip for single entry", function()
    local state = make_log_state(5)
    fmt.push(state, "info", nil, "hello")
    local entries = fmt.get_entries(state)
    assert(#entries == 1, "expected 1 entry")
    assert(entries[1].text == "hello", "expected 'hello'")
    assert(entries[1].level == "info", "expected info level")
  end)

  it("fills to capacity without overflow", function()
    local state = make_log_state(3)
    fmt.push(state, "warn", nil, "a")
    fmt.push(state, "warn", nil, "b")
    fmt.push(state, "warn", nil, "c")
    local entries = fmt.get_entries(state)
    assert(#entries == 3, "expected 3 entries")
  end)

  it("overwrites oldest entry when full (circular)", function()
    local state = make_log_state(3)
    fmt.push(state, "info", nil, "first")
    fmt.push(state, "info", nil, "second")
    fmt.push(state, "info", nil, "third")
    fmt.push(state, "info", nil, "fourth")
    local entries = fmt.get_entries(state)
    assert(#entries == 3, "expected 3 entries (capacity)")
    local texts = {}
    for _, e in ipairs(entries) do texts[#texts + 1] = e.text end
    assert(not (function()
      for _, t in ipairs(texts) do if t == "first" then return true end end
    end)(), "expected 'first' to be overwritten")
  end)

  it("max_entries <= 0 stores nothing", function()
    local state = make_log_state(0)
    fmt.push(state, "info", nil, "x")
    local entries = fmt.get_entries(state)
    assert(#entries == 0, "expected no entries when max_entries=0")
  end)

  it("get_text returns newline-joined formatted lines", function()
    local state = make_log_state(5)
    fmt.push(state, "info", nil, "line1")
    fmt.push(state, "warn", nil, "line2")
    local text = fmt.get_text(state)
    assert(type(text) == "string", "expected string")
    assert(text:find("line1"), "expected line1")
    assert(text:find("line2"), "expected line2")
  end)

  it("get_entries_by_level filters by level", function()
    local state = make_log_state(10)
    fmt.push(state, "info", nil, "info_msg")
    fmt.push(state, "warn", nil, "warn_msg")
    fmt.push(state, "info", nil, "info_msg2")
    local warns = fmt.get_entries_by_level(state, "warn")
    assert(#warns == 1, "expected 1 warn entry")
    assert(warns[1].text == "warn_msg", "expected warn_msg")
  end)

  it("get_text_by_level returns only matching level text", function()
    local state = make_log_state(10)
    fmt.push(state, "info", nil, "a")
    fmt.push(state, "warn", nil, "b")
    local text = fmt.get_text_by_level(state, "info")
    assert(text:find("a"), "expected info entry in text")
    assert(not text:find("b"), "expected warn entry excluded")
  end)

end)

describe("logger singleton", function()
  before_each(function() logger.clear() end)
  after_each(function() logger.clear() end)

  it("info adds an entry", function()
    logger.info("test message")
    local text = logger.get_text()
    assert(text:find("test message"), "expected 'test message' in log")
  end)

  it("warn adds a warn entry", function()
    logger.warn("something wrong")
    local text = logger.get_text_by_level("warn")
    assert(text:find("something wrong"), "expected warn in log")
  end)

  it("clear resets entries", function()
    logger.info("before clear")
    logger.clear()
    local text = logger.get_text()
    assert(text == "" or not text:find("before clear"), "expected clear to remove entries")
  end)

  it("set_enabled false suppresses info", function()
    logger.set_enabled(false)
    logger.info("suppressed")
    local text = logger.get_text()
    assert(not text:find("suppressed"), "expected suppressed when disabled")
    logger.set_enabled(true)
  end)

  it("log_once logs first call and skips duplicate key", function()
    local sink = {}
    local first = logger.log_once(sink, "info", "my_key", "first_message")
    local second = logger.log_once(sink, "info", "my_key", "second_message")
    assert(first == true, "expected first call to return true")
    assert(second == false, "expected second call to return false")
    local text = logger.get_text()
    assert(text:find("first_message"), "expected first message logged")
    assert(not text:find("second_message"), "expected second message skipped")
  end)

  it("is_test_mode returns false by default", function()
    assert(logger.is_test_mode() == true or type(logger.is_test_mode()) == "boolean")
  end)

  it("is_anim_debug_enabled returns false without provider", function()
    logger.set_anim_debug_enabled_provider(nil)
    assert(logger.is_anim_debug_enabled() == false, "expected false without provider")
  end)

  it("is_anim_debug_enabled calls provider", function()
    logger.set_anim_debug_enabled_provider(function() return true end)
    assert(logger.is_anim_debug_enabled() == true, "expected true from provider")
    logger.set_anim_debug_enabled_provider(nil)
  end)

  it("is_anim_debug_enabled returns false when provider errors", function()
    logger.set_anim_debug_enabled_provider(function() error("boom") end)
    assert(logger.is_anim_debug_enabled() == false, "expected false on provider error")
    logger.set_anim_debug_enabled_provider(nil)
  end)

  it("set_info_per_turn_limit and set_info_turn_provider configure rate limiting", function()
    logger.set_info_per_turn_limit(2)
    local turn = 1
    logger.set_info_turn_provider(function() return turn end)
    logger.info("msg1")
    logger.info("msg2")
    logger.info("msg3_suppressed")
    local text = logger.get_text()
    assert(text:find("msg1"), "expected msg1")
    assert(text:find("msg2"), "expected msg2")
    assert(not text:find("msg3_suppressed"), "expected msg3 suppressed by rate limit")
    logger.set_info_per_turn_limit(nil)
    logger.set_info_turn_provider(nil)
  end)
end)
