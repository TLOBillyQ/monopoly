if not math.tofixed then
  math.tofixed = function(v) return v end
end

local tick_clock = require("src.turn.loop.tick_clock")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_state(now_fn, diff_fn)
  return {
    gameplay_loop_ports = {
      clock = {
        wall_now_seconds = now_fn,
        wall_diff_seconds = diff_fn,
      },
    },
  }
end

local function test_resolve_fallback_tick_seconds_divides_by_fps()
  local result = tick_clock.resolve_fallback_tick_seconds(60)
  assert(type(result) == "number", "resolve_fallback_tick_seconds should return a number")
  assert(result > 0, "resolve_fallback_tick_seconds should return positive value")
end

local function test_resolve_tick_seconds_nil_state_returns_fallback()
  local dt, reason = tick_clock.resolve_tick_seconds(nil, 0.033)
  _assert_eq(dt, 0.033, "nil state should return fallback_seconds")
  _assert_eq(reason, "fallback:no_state", "nil state reason should be fallback:no_state")
end

local function test_resolve_tick_seconds_no_clock_returns_fallback()
  local state = { gameplay_loop_ports = {} }
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "no clock should return fallback_seconds")
  _assert_eq(reason, "fallback:no_clock", "no clock reason should be fallback:no_clock")
end

local function test_resolve_tick_seconds_no_ports_returns_fallback()
  local state = {}
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.016)
  _assert_eq(dt, 0.016, "no ports should return fallback_seconds")
  _assert_eq(reason, "fallback:no_clock", "no ports reason should be fallback:no_clock")
end

local function test_resolve_tick_seconds_wall_now_not_function_returns_fallback()
  local state = {
    gameplay_loop_ports = {
      clock = {
        wall_now_seconds = "not_a_function",
        wall_diff_seconds = function(a, b) return a - b end,
      },
    },
  }
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "non-function now should return fallback_seconds")
  _assert_eq(reason, "fallback:now_invalid", "non-function now reason should be fallback:now_invalid")
end

local function test_resolve_tick_seconds_wall_now_returns_nil_returns_fallback()
  local state = _make_state(
    function() return nil end,
    function(a, b) return a - b end
  )
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "nil now should return fallback_seconds")
  _assert_eq(reason, "fallback:now_invalid", "nil now reason should be fallback:now_invalid")
end

local function test_resolve_tick_seconds_first_call_returns_no_previous()
  local state = _make_state(
    function() return 100.5 end,
    function(a, b) return a - b end
  )
  local dt, reason, now_out = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "first call (no previous) should return fallback_seconds")
  _assert_eq(reason, "fallback:no_previous", "first call reason should be fallback:no_previous")
  _assert_eq(now_out, 100.5, "now should be passed through")
end

local function test_resolve_tick_seconds_integer_like_times_returns_coarse_fallback()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.0 or 11.0
    end,
    function(a, b) return a - b end
  )
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "integer-like times should return fallback_seconds")
  _assert_eq(reason, "fallback:coarse_wall_clock", "integer-like times reason should be fallback:coarse_wall_clock")
end

local function test_resolve_tick_seconds_normal_diff_uses_wall_diff()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.1 or 10.3
    end,
    function(a, b) return a - b end
  )
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  assert(dt ~= nil and dt > 0, "normal diff should return positive dt")
  _assert_eq(reason, "wall:diff", "normal diff reason should be wall:diff")
end

local function test_resolve_tick_seconds_reversed_diff_uses_wall_diff_reversed()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.3 or 10.1
    end,
    function(a, b) return a - b end
  )
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  assert(dt ~= nil and dt > 0, "reversed diff should return positive dt via reverse")
  _assert_eq(reason, "wall:diff_reversed", "reversed diff reason should be wall:diff_reversed")
end

local function test_resolve_tick_seconds_fallback_to_raw_diff_when_wall_diff_non_numeric()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.1 or 10.3
    end,
    function() return nil end
  )
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  assert(dt ~= nil and dt > 0, "raw diff fallback should return positive dt")
  _assert_eq(reason, "wall:raw_diff", "raw diff reason should be wall:raw_diff")
end

local function test_resolve_tick_seconds_raw_diff_reversed_when_both_negative()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.3 or 10.1
    end,
    function() return nil end
  )
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  assert(dt ~= nil and dt > 0, "raw reversed diff should return positive dt")
  _assert_eq(reason, "wall:raw_diff_reversed", "raw reversed reason should be wall:raw_diff_reversed")
end

local function test_resolve_tick_seconds_all_diff_fail_returns_diff_invalid()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.5 or 10.5
    end,
    function() return nil end
  )
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "all diff fail should return fallback_seconds")
  _assert_eq(reason, "fallback:diff_invalid", "all diff fail reason should be fallback:diff_invalid")
end

local function test_resolve_tick_seconds_diff_capped_at_one()
  local call_count = 0
  local state = _make_state(
    function()
      call_count = call_count + 1
      return call_count == 1 and 10.0 or 15.0
    end,
    function(a, b) return a - b end
  )
  state.gameplay_loop_ports.clock.wall_now_seconds = function()
    call_count = call_count + 1
    if call_count == 1 then return 10.1 end
    return 20.5
  end
  tick_clock.resolve_tick_seconds(state, 0.033)
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 1.0, "diff > 1.0 should be capped at 1.0")
  _assert_eq(reason, "wall:diff", "capped diff reason should be wall:diff")
end

return {
  name = "domain tick clock coverage",
  tests = {
    { name = "resolve_fallback_tick_seconds divides by fps", run = test_resolve_fallback_tick_seconds_divides_by_fps },
    { name = "resolve_tick_seconds nil state returns fallback", run = test_resolve_tick_seconds_nil_state_returns_fallback },
    { name = "resolve_tick_seconds no clock returns fallback", run = test_resolve_tick_seconds_no_clock_returns_fallback },
    { name = "resolve_tick_seconds no ports returns fallback", run = test_resolve_tick_seconds_no_ports_returns_fallback },
    { name = "resolve_tick_seconds wall_now not function returns fallback", run = test_resolve_tick_seconds_wall_now_not_function_returns_fallback },
    { name = "resolve_tick_seconds wall_now returns nil returns fallback", run = test_resolve_tick_seconds_wall_now_returns_nil_returns_fallback },
    { name = "resolve_tick_seconds first call returns no previous", run = test_resolve_tick_seconds_first_call_returns_no_previous },
    { name = "resolve_tick_seconds integer-like times returns coarse fallback", run = test_resolve_tick_seconds_integer_like_times_returns_coarse_fallback },
    { name = "resolve_tick_seconds normal diff uses wall:diff", run = test_resolve_tick_seconds_normal_diff_uses_wall_diff },
    { name = "resolve_tick_seconds reversed diff uses wall:diff_reversed", run = test_resolve_tick_seconds_reversed_diff_uses_wall_diff_reversed },
    { name = "resolve_tick_seconds fallback to raw diff when wall_diff non-numeric", run = test_resolve_tick_seconds_fallback_to_raw_diff_when_wall_diff_non_numeric },
    { name = "resolve_tick_seconds raw diff reversed when both negative", run = test_resolve_tick_seconds_raw_diff_reversed_when_both_negative },
    { name = "resolve_tick_seconds all diff fail returns diff_invalid", run = test_resolve_tick_seconds_all_diff_fail_returns_diff_invalid },
    { name = "resolve_tick_seconds diff capped at one", run = test_resolve_tick_seconds_diff_capped_at_one },
  },
}
