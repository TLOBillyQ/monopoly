-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):单 describe「domain tick clock
-- coverage」带 before_each,拍平为 TestTickClock 类(setUp 承接);用例数与
-- 改写前一一对应(14 例)。

if not math.tofixed then
  math.tofixed = function(v) return v end
end

local lu = require("luaunit")
local tick_clock = require("src.turn.loop.tick_clock")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local _config_reset = require("test.support.config_reset")
local _saved_fps = runtime_constants.fps

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

TestTickClock = {}

function TestTickClock:setUp()
  _config_reset.reset_all()
end

function TestTickClock:tearDown()
  runtime_constants.fps = _saved_fps
end

function TestTickClock:test_resolve_fallback_tick_seconds_divides_by_fps()
  local result = tick_clock.resolve_fallback_tick_seconds(60)
  lu.assertEvalToTrue(type(result) == "number", "resolve_fallback_tick_seconds should return a number")
  lu.assertEvalToTrue(result > 0, "resolve_fallback_tick_seconds should return positive value")
end

function TestTickClock:test_resolve_fallback_tick_seconds_uses_30fps_for_invalid_fps()
  -- L8 `not number_utils.is_numeric(fps) or fps <= 0` 的 `not` 删除:非数值 fps
  -- 变异体对 "abc" <= 0 撞比较错;基线落 30.0 默认。
  runtime_constants.fps = "abc"
  local result = tick_clock.resolve_fallback_tick_seconds(60)
  _assert_eq(result, 60 / 30.0, "invalid fps must fall back to the 30fps default")
end

function TestTickClock:test_resolve_fallback_tick_seconds_keeps_a_valid_fps()
  -- L8 `number_utils.is_numeric(fps)` 换 nil:合法 fps=60 必须被采用,
  -- 变异体恒落 30.0。
  runtime_constants.fps = 60
  local result = tick_clock.resolve_fallback_tick_seconds(60)
  _assert_eq(result, 1.0, "valid fps must be used for the division")
end

function TestTickClock:test_resolve_fallback_tick_seconds_clamps_zero_fps()
  -- L8 `not is_numeric(fps) or fps <= 0` 的 or->and:fps=0 必须被钳到 30.0,
  -- 变异体保留 0 导致除零得 inf。
  runtime_constants.fps = 0
  local result = tick_clock.resolve_fallback_tick_seconds(60)
  _assert_eq(result, 2.0, "zero fps must be clamped to the 30fps default")
end

function TestTickClock:test_resolve_fallback_tick_seconds_keeps_fps_one()
  -- L8 `fps <= 0` 的 0->1:fps=1 是合法值,变异体 `1 <= 1` 误钳到 30.0。
  runtime_constants.fps = 1
  local result = tick_clock.resolve_fallback_tick_seconds(60)
  _assert_eq(result, 60.0, "fps=1 must not be clamped")
end

function TestTickClock:test_resolve_tick_fallback_carries_state_wall_time_through()
  -- L113 `state and state.tick_wall_now_seconds or nil` 的 or->and:回退结果
  -- 必须携带 state 上已记录的 wall 时间。
  local state = { tick_wall_now_seconds = 42.5 }
  local dt, reason, now_out = tick_clock.resolve_tick_seconds(state, 0.016)
  _assert_eq(dt, 0.016, "no ports should return fallback_seconds")
  _assert_eq(reason, "fallback:no_clock", "no ports reason should be fallback:no_clock")
  _assert_eq(now_out, 42.5, "fallback must carry the state wall time through")
end

function TestTickClock:test_resolve_tick_seconds_rejects_partial_clock_pair()
  -- L148 `not wall_now_seconds or not wall_diff_seconds` 的 or->and:只有
  -- wall_now 没有 wall_diff 的时钟对必须整体拒绝(no_clock),变异体放行
  -- 后走进 raw-diff 分叉产出别的 reason。
  local state = {
    gameplay_loop_ports = {
      clock = {
        wall_now_seconds = function()
          return 100.5
        end,
        wall_diff_seconds = nil,
      },
    },
  }
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "partial clock pair should return fallback_seconds")
  _assert_eq(reason, "fallback:no_clock", "partial clock pair must be rejected as no_clock")
end

function TestTickClock:test_resolve_tick_seconds_nil_state_returns_fallback()
  local dt, reason = tick_clock.resolve_tick_seconds(nil, 0.033)
  _assert_eq(dt, 0.033, "nil state should return fallback_seconds")
  _assert_eq(reason, "fallback:no_state", "nil state reason should be fallback:no_state")
end

function TestTickClock:test_resolve_tick_seconds_no_clock_returns_fallback()
  local state = { gameplay_loop_ports = {} }
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "no clock should return fallback_seconds")
  _assert_eq(reason, "fallback:no_clock", "no clock reason should be fallback:no_clock")
end

function TestTickClock:test_resolve_tick_seconds_no_ports_returns_fallback()
  local state = {}
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.016)
  _assert_eq(dt, 0.016, "no ports should return fallback_seconds")
  _assert_eq(reason, "fallback:no_clock", "no ports reason should be fallback:no_clock")
end

function TestTickClock:test_resolve_tick_seconds_wall_now_not_function_returns_fallback()
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

function TestTickClock:test_resolve_tick_seconds_wall_now_returns_nil_returns_fallback()
  local state = _make_state(
    function() return nil end,
    function(a, b) return a - b end
  )
  local dt, reason = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "nil now should return fallback_seconds")
  _assert_eq(reason, "fallback:now_invalid", "nil now reason should be fallback:now_invalid")
end

function TestTickClock:test_resolve_tick_seconds_first_call_returns_no_previous()
  local state = _make_state(
    function() return 100.5 end,
    function(a, b) return a - b end
  )
  local dt, reason, now_out = tick_clock.resolve_tick_seconds(state, 0.033)
  _assert_eq(dt, 0.033, "first call (no previous) should return fallback_seconds")
  _assert_eq(reason, "fallback:no_previous", "first call reason should be fallback:no_previous")
  _assert_eq(now_out, 100.5, "now should be passed through")
end

function TestTickClock:test_resolve_tick_seconds_integer_like_times_returns_coarse_fallback()
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

function TestTickClock:test_resolve_tick_seconds_normal_diff_uses_wall_diff()
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
  lu.assertEvalToTrue(dt ~= nil and dt > 0, "normal diff should return positive dt")
  _assert_eq(reason, "wall:diff", "normal diff reason should be wall:diff")
end

function TestTickClock:test_resolve_tick_seconds_reversed_diff_uses_wall_diff_reversed()
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
  lu.assertEvalToTrue(dt ~= nil and dt > 0, "reversed diff should return positive dt via reverse")
  _assert_eq(reason, "wall:diff_reversed", "reversed diff reason should be wall:diff_reversed")
end

function TestTickClock:test_resolve_tick_seconds_fallback_to_raw_diff_when_wall_diff_non_numeric()
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
  lu.assertEvalToTrue(dt ~= nil and dt > 0, "raw diff fallback should return positive dt")
  _assert_eq(reason, "wall:raw_diff", "raw diff reason should be wall:raw_diff")
end

function TestTickClock:test_resolve_tick_seconds_raw_diff_reversed_when_both_negative()
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
  lu.assertEvalToTrue(dt ~= nil and dt > 0, "raw reversed diff should return positive dt")
  _assert_eq(reason, "wall:raw_diff_reversed", "raw reversed reason should be wall:raw_diff_reversed")
end

function TestTickClock:test_resolve_tick_seconds_all_diff_fail_returns_diff_invalid()
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

function TestTickClock:test_resolve_tick_seconds_diff_capped_at_one()
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


return TestTickClock
