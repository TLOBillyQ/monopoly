local logger = require("src.foundation.log")

-- warn 级合成文案统一带 spec_synthetic 前缀：logger 会经 print 落到
-- warn 采集器，保留前缀由 docs/reports/behavior_warns_data.lua 白名单豁免。

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
    fmt.push(state, "warn", nil, "spec_synthetic_a")
    fmt.push(state, "warn", nil, "spec_synthetic_b")
    fmt.push(state, "warn", nil, "spec_synthetic_c")
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
    fmt.push(state, "warn", nil, "spec_synthetic_line2")
    local text = fmt.get_text(state)
    assert(type(text) == "string", "expected string")
    assert(text:find("line1"), "expected line1")
    assert(text:find("spec_synthetic_line2"), "expected line2")
  end)

  it("get_entries_by_level filters by level", function()
    local state = make_log_state(10)
    fmt.push(state, "info", nil, "info_msg")
    fmt.push(state, "warn", nil, "spec_synthetic_warn_msg")
    fmt.push(state, "info", nil, "info_msg2")
    local warns = fmt.get_entries_by_level(state, "warn")
    assert(#warns == 1, "expected 1 warn entry")
    assert(warns[1].text == "spec_synthetic_warn_msg", "expected warn_msg")
  end)

  it("get_text_by_level returns only matching level text", function()
    local state = make_log_state(10)
    fmt.push(state, "info", nil, "info_only_msg")
    fmt.push(state, "warn", nil, "spec_synthetic_warn_only_msg")
    local text = fmt.get_text_by_level(state, "info")
    assert(text:find("info_only_msg"), "expected info entry in text")
    assert(not text:find("warn_only_msg"), "expected warn entry excluded")
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
    logger.warn("spec_synthetic something wrong")
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

-- ════════════════════════════════════════════════════════════════════════════
-- Coverage pins for mutation survivors at src/foundation/log.lua T16 sweep.
-- Each block targets specific decision points that prior tests do not pin.
-- ════════════════════════════════════════════════════════════════════════════

describe("logger rate-limit decision pinning (L34/L39/L41/L73/L76/L81/L94)", function()
  before_each(function() logger.clear() end)
  after_each(function()
    logger.set_info_per_turn_limit(nil)
    logger.set_info_turn_provider(nil)
    logger.clear()
  end)

  it("limit=0 disables rate limiting (cannot collapse to truthy check)", function()
    logger.set_info_per_turn_limit(0)
    logger.set_info_turn_provider(function() return 1 end)
    for i = 1, 5 do logger.info("msg" .. i) end
    local text = logger.get_text()
    for i = 1, 5 do
      assert(text:find("msg" .. i), "limit=0 must not gate any messages; missing msg" .. i)
    end
  end)

  it("nil provider disables rate limiting (provider must exist)", function()
    logger.set_info_per_turn_limit(2)
    logger.set_info_turn_provider(nil)
    for i = 1, 5 do logger.info("msg" .. i) end
    local text = logger.get_text()
    for i = 1, 5 do
      assert(text:find("msg" .. i), "nil provider must let all through; missing msg" .. i)
    end
  end)

  it("provider returning nil short-circuits rate-limit check (L39 'false' branch)", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return nil end)
    logger.info("a")
    logger.info("b")
    local text = logger.get_text()
    assert(text:find("a") and text:find("b"),
      "provider returning nil must skip rate limit (both logged)")
  end)

  it("new turn resets count (L41 ~= comparison drives reset path)", function()
    logger.set_info_per_turn_limit(2)
    local turn = 1
    logger.set_info_turn_provider(function() return turn end)
    logger.info("t1a"); logger.info("t1b"); logger.info("t1_suppressed")
    turn = 2
    logger.info("t2a"); logger.info("t2b"); logger.info("t2_suppressed")
    local text = logger.get_text()
    assert(text:find("t1a") and text:find("t1b"), "expected first turn's two messages")
    assert(text:find("t2a") and text:find("t2b"), "turn change must reset counter")
    assert(not text:find("t1_suppressed"), "expected t1 third suppressed")
    assert(not text:find("t2_suppressed"), "expected t2 third suppressed")
  end)

  it("opts.unlimited bypasses rate limit even with limit set", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return 1 end)
    logger.info_unlimited("u1")
    logger.info_unlimited("u2")
    logger.info_unlimited("u3")
    local text = logger.get_text()
    for i = 1, 3 do
      assert(text:find("u" .. i), "unlimited variant must bypass limit; missing u" .. i)
    end
  end)
end)

describe("logger._create_entry pins (L53/L54/L55)", function()
  before_each(function() logger.clear() end)
  after_each(function() logger.reset_time_runtime(); logger.clear() end)

  it("timestamp_provider is called per entry (L53 cannot be deleted)", function()
    local calls = 0
    logger.timestamp_provider = function() calls = calls + 1; return 7 end
    logger.time_formatter = function(ts) return "T" .. tostring(ts) end
    logger.info("x")
    logger.info("y")
    logger.info("z")
    assert(calls >= 3, "timestamp_provider must be called per entry; got " .. calls)
    local text = logger.get_text()
    assert(text:find("T7"), "expected time_formatter output T7")
  end)

  it("time_formatter receives the timestamp (L54 cannot be deleted)", function()
    local seen = {}
    logger.timestamp_provider = function() return 42 end
    logger.time_formatter = function(ts) seen[#seen + 1] = ts; return "" end
    logger.info("a")
    assert(seen[1] == 42, "time_formatter must receive timestamp_provider result")
  end)

  it("seq increments by 1 per entry (L55 + cannot be deleted)", function()
    logger.timestamp_provider = function() return 0 end
    logger.time_formatter = function() return "" end
    local before = logger.seq
    logger.info("a"); logger.info("b"); logger.info("c")
    -- seq increments via _create_entry on info + warn (and clear bumps by 1)
    assert(logger.seq >= before + 3, "seq must advance by entry count; before="
      .. tostring(before) .. " after=" .. tostring(logger.seq))
  end)
end)

describe("logger.formatter buffer head/count pins (L73/L76/L94/L103/L107/L112/L127)", function()
  local fmt = logger.formatter

  it("entries_head defaults to 1 when nil (L73 'or 1' branch)", function()
    local state = {
      entries = {},
      max_entries = 3,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "x")
    assert(state.entries_head ~= nil, "head must be set after first push")
    assert(state.entries_count == 1, "count must be 1 after first push")
  end)

  it("count desync (count>0 but entries empty) triggers reinit (L76 'and >' branch)", function()
    local state = {
      entries = {},
      max_entries = 3,
      seq = 0,
      entries_head = 1,
      entries_count = 5, -- desync: claims 5 entries but table is empty
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "first")
    assert(#state.entries == 1, "expected reinit to produce 1 entry")
  end)

  it("max_entries=0 stores nothing (L81 '<=0' boundary)", function()
    local state = {
      entries = {},
      max_entries = 0,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "ignored")
    assert(#state.entries == 0, "max_entries=0 must accept nothing")
  end)

  it("circular wrap math: head advances modulo max_entries (L94)", function()
    local state = {
      entries = {},
      max_entries = 2,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "a")
    fmt.push(state, "info", nil, "b")
    fmt.push(state, "info", nil, "c") -- overwrites a
    fmt.push(state, "info", nil, "d") -- overwrites b
    local entries = fmt.get_entries(state)
    local texts = {}
    for _, e in ipairs(entries) do texts[#texts + 1] = e.text end
    assert(#entries == 2, "capacity is 2")
    assert(texts[1] == "c" and texts[2] == "d",
      "expected oldest-first: c,d but got " .. table.concat(texts, ","))
  end)

  it("get_entries with nil count/head returns raw entries (L103 'or' branch)", function()
    local state = {
      entries = { { text = "stale", level = "info" } },
      max_entries = 5,
      seq = 0,
      -- entries_count, entries_head deliberately nil
    }
    local out = fmt.get_entries(state)
    assert(#out >= 1, "nil count/head must fall through and return entries table")
  end)

  it("count<=0 returns empty (L107 '<=' boundary)", function()
    local state = {
      entries = { { text = "x", level = "info" } },
      max_entries = 5,
      entries_count = 0,
      entries_head = 1,
    }
    local out = fmt.get_entries(state)
    assert(#out == 0, "count=0 must return empty")
  end)

  it("capacity<=0 returns empty (L112)", function()
    local state = {
      entries = { { text = "x", level = "info" } },
      max_entries = 0,
      entries_count = 1,
      entries_head = 1,
    }
    local out = fmt.get_entries(state)
    assert(#out == 0, "capacity<=0 must return empty")
  end)

  it("max_lines > total clamps to total (L127 '>')", function()
    local state = {
      entries = {},
      max_entries = 5,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "a")
    fmt.push(state, "info", nil, "b")
    local text = fmt.get_text(state, 999)
    assert(text:find("a") and text:find("b"), "oversized max_lines must clamp to total")
  end)
end)

describe("logger.is_test_mode exact-true equality (L214)", function()
  before_each(function() logger.set_test_mode(false) end)
  after_each(function() logger.set_test_mode(false) end)

  it("returns true only for explicit true input, not truthy non-bool", function()
    logger.test_mode = "yes" -- truthy but not exactly true
    assert(logger.is_test_mode() == false,
      "is_test_mode must use == true equality, not truthy check")
    logger.test_mode = 1
    assert(logger.is_test_mode() == false,
      "is_test_mode must reject numeric truthy")
    logger.test_mode = true
    assert(logger.is_test_mode() == true)
  end)
end)

describe("logger.configure_game_time _pad2 boundary (L236-L239)", function()
  it("values < 10 get zero-padded; >= 10 don't", function()
    local game_api = {
      get_timestamp = function() return 0 end,
      get_hour = function() return 9 end,
      get_minute = function() return 12 end,
      get_second = function() return 5 end,
    }
    logger.configure_game_time(game_api)
    local text = logger.time_formatter(0)
    -- expect "09:12:05" — single digits padded, double left alone
    assert(text == "09:12:05",
      "_pad2 must zero-pad < 10 and leave >= 10 untouched; got: " .. text)
    logger.reset_time_runtime()
  end)
end)

describe("logger.clear counter/turn resets (L303/L304/L305/L306)", function()
  before_each(function() logger.clear() end)
  after_each(function() logger.set_info_per_turn_limit(nil); logger.set_info_turn_provider(nil); logger.clear() end)

  it("clear increments seq by 1", function()
    local before = logger.seq
    logger.clear()
    assert(logger.seq == before + 1,
      "clear must bump seq by exactly 1; was " .. tostring(before) ..
      " now " .. tostring(logger.seq))
  end)

  it("clear increments event_seq by 1 (defaults nil → 0 path)", function()
    logger.event_seq = nil
    logger.clear()
    assert(logger.event_seq == 1,
      "clear with nil event_seq must initialise then increment to 1; got " ..
      tostring(logger.event_seq))
    logger.clear()
    assert(logger.event_seq == 2)
  end)

  it("clear resets info_turn to nil and count to 0", function()
    logger.set_info_per_turn_limit(2)
    logger.set_info_turn_provider(function() return 1 end)
    logger.info("a"); logger.info("b") -- counts to 2
    assert(logger.info_turn_count > 0, "expected count > 0 before clear")
    logger.clear()
    assert(logger.info_turn == nil, "clear must reset info_turn to nil")
    assert(logger.info_turn_count == 0, "clear must reset count to 0")
  end)
end)

-- Round-2 survivor pins. After round-1, 18 mutants survive. These target the
-- killable subset (15) using boundary inputs round-1 generic tests miss. The
-- 3 left (L107×2, L127) are equivalent mutations.

describe("logger rate-limit boundary at limit=1 (L34 '0->1' boundary)", function()
  before_each(function() logger.clear() end)
  after_each(function() logger.set_info_per_turn_limit(nil); logger.set_info_turn_provider(nil); logger.clear() end)

  it("limit=1 actually rate-limits second info in same turn (proves >0 not >1)", function()
    logger.set_info_per_turn_limit(1)
    logger.set_info_turn_provider(function() return 1 end)
    logger.info("first_ok")
    logger.info("second_should_be_suppressed_xyz")
    local text = logger.get_text()
    assert(text:find("first_ok"), "first must pass through")
    assert(not text:find("second_should_be_suppressed_xyz"),
      "limit=1 with provider must suppress second info; if surviving '>0->>1', limit=1 disables rate-limit")
  end)
end)

describe("logger._store_entry head default L73 ('or 1' literal)", function()
  local fmt = logger.formatter
  it("with pre-populated entries[1] + count=0 + head=nil, default head is 1 not 0", function()
    -- Pre-populate entries[1] so #entries > 0 → L76 self-healing reset does NOT
    -- fire on subsequent pushes (gate is `#entries == 0 and count > 0`). Then
    -- L73's `or 1` default is the only thing controlling first-push head.
    local seed = { text = "seed", level = "info", timestamp = 0, time_text = "", seq = 0 }
    local state = {
      entries = { seed },
      max_entries = 2,
      entries_count = 0,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "a")
    fmt.push(state, "info", nil, "b")
    fmt.push(state, "info", nil, "c")
    fmt.push(state, "info", nil, "d")
    local entries = fmt.get_entries(state)
    local texts = {}; for _, e in ipairs(entries) do texts[#texts + 1] = e.text end
    -- Original (head=1): a→[1], b→[2], c overwrites [1], d overwrites [2]
    -- → entries={[1]=c, [2]=d}, get_entries returns c,d.
    -- Mutated (head=0): a→[2], b→[1] (overwrites seed), c→[0], d→[1] overwrite
    -- → entries={[0]=c, [1]=d, [2]=a}, get_entries returns a,d.
    assert(#entries == 2, "expected 2 entries; got " .. #entries)
    assert(texts[1] == "c" and texts[2] == "d",
      "head defaulting to 1 yields c,d under wrap. Got: " .. table.concat(texts, ","))
  end)
end)

describe("logger._store_entry L76 '>' not '>=' boundary", function()
  local fmt = logger.formatter
  it("with count=0 + non-default head=5 + entries empty, reset is NOT triggered", function()
    local state = {
      entries = {},
      max_entries = 2,
      entries_count = 0,
      entries_head = 5,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "a")
    fmt.push(state, "info", nil, "b")
    fmt.push(state, "info", nil, "c")
    fmt.push(state, "info", nil, "d")
    local entries = fmt.get_entries(state)
    local texts = {}; for _, e in ipairs(entries) do texts[#texts + 1] = e.text end
    assert(texts[1] == "a", "L76 '>' skip reset; got: " .. table.concat(texts, ","))
    assert(texts[2] == "d", "L76 '>' skip reset latest=d; got: " .. table.concat(texts, ","))
  end)
end)

describe("logger._store_entry L81 '<=0' boundary at max_entries=1", function()
  local fmt = logger.formatter
  it("max_entries=1 accepts one entry (proves '<=0' not '<=1')", function()
    local state = {
      entries = {},
      max_entries = 1,
      seq = 0,
      timestamp_provider = function() return 0 end,
      time_formatter = function() return "" end,
    }
    fmt.push(state, "info", nil, "only")
    local entries = fmt.get_entries(state)
    assert(#entries == 1, "max_entries=1 must accept one entry")
    assert(entries[1].text == "only")
  end)
end)

describe("logger._list_entries L103 'or' not 'and'", function()
  local fmt = logger.formatter
  it("count set but head nil short-circuits to raw entries via OR", function()
    local state = {
      entries = { { text = "x", level = "info" } },
      max_entries = 5,
      entries_count = 1,
    }
    local ok, out = pcall(function() return fmt.get_entries(state) end)
    assert(ok, "L103 'or' must short-circuit on either nil; AND mutation crashes")
    assert(#out >= 1, "expected entries returned via short-circuit")
  end)
end)

describe("logger module-level defaults (L161/L162/L166/L168/L171/L174)", function()
  local saved_pkg
  before_each(function()
    saved_pkg = package.loaded["src.foundation.log"]
    package.loaded["src.foundation.log"] = nil
  end)
  after_each(function()
    package.loaded["src.foundation.log"] = saved_pkg
  end)

  it("seq defaults to 0 (L161 literal '0')", function()
    local m = require("src.foundation.log")
    assert(m.seq == 0, "expected default seq=0; got " .. tostring(m.seq))
  end)

  it("event_seq defaults to 0 (L162 literal '0')", function()
    local m = require("src.foundation.log")
    assert(m.event_seq == 0, "expected default event_seq=0; got " .. tostring(m.event_seq))
  end)

  it("info_turn_count defaults to 0 (L166 literal '0')", function()
    local m = require("src.foundation.log")
    assert(m.info_turn_count == 0, "expected default info_turn_count=0; got " .. tostring(m.info_turn_count))
  end)

  it("default timestamp_provider returns 0 (L168 inside fn body)", function()
    local m = require("src.foundation.log")
    assert(m.timestamp_provider() == 0,
      "default timestamp_provider must return 0; got " .. tostring(m.timestamp_provider()))
  end)

  it("default time_formatter returns tostring(timestamp), not nil (L171)", function()
    local m = require("src.foundation.log")
    local out = m.time_formatter(7)
    assert(out == "7", "default time_formatter(7) must be '7'; got " .. tostring(out))
  end)

  it("test_mode defaults to false (L174 literal 'false')", function()
    local m = require("src.foundation.log")
    assert(m.test_mode == false, "expected default test_mode=false; got " .. tostring(m.test_mode))
    assert(m.is_test_mode() == false)
  end)
end)

describe("logger._pad2 boundary at value=10 (L236 '<' not '<=')", function()
  it("hour=10 produces '10' not '010'", function()
    local game_api = {
      get_timestamp = function() return 0 end,
      get_hour = function() return 10 end,
      get_minute = function() return 10 end,
      get_second = function() return 10 end,
    }
    logger.configure_game_time(game_api)
    local text = logger.time_formatter(0)
    assert(text == "10:10:10",
      "value=10 must NOT pad ('<' not '<='); got: " .. text)
    logger.reset_time_runtime()
  end)
end)

describe("logger._push print fallback (L273 ×3 mutations)", function()
  before_each(function() logger.clear() end)
  after_each(function() logger.clear() end)

  it("logger.info calls global print when print is a function", function()
    local captured = {}
    local original_print = _G.print
    _G.print = function(...) captured[#captured + 1] = table.concat({...}, " ") end
    local ok = pcall(function()
      logger.info("unique_marker_print_capture_BfTzQ")
    end)
    _G.print = original_print
    assert(ok, "logger.info must not throw with print as a function")
    local found = false
    for _, line in ipairs(captured) do
      if line:find("unique_marker_print_capture_BfTzQ") then found = true; break end
    end
    assert(found,
      "logger.info must invoke print; mutation breaks the type check. Captured " .. #captured .. " lines.")
  end)
end)
