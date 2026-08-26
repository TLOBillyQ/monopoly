local number_utils = require("src.foundation.number")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local tick_clock = {}

local function _resolve_fallback_tick_seconds(interval)
  local fps = runtime_constants.fps
  if not number_utils.is_numeric(fps) or fps <= 0 then
    fps = 30.0
  end
  return math.tofixed(interval) / fps
end

local function _normalize_positive_dt(value)
  if not number_utils.is_numeric(value) or value <= 0 then
    return nil
  end
  if value > 1.0 then
    return 1.0
  end
  return value
end

local function _is_integer_like_time(value)
  if not number_utils.is_numeric(value) then
    return false
  end
  local as_int = number_utils.to_integer(value)
  if as_int == nil then
    return false
  end
  return value == as_int
end

local function _resolve_clock_from_state(state)
  if not state then
    return nil
  end
  local ports = state.gameplay_loop_ports
  return ports and ports.clock or nil
end

local function _resolve_wall_functions(clock)
  if not clock then
    return nil, nil
  end
  return clock.wall_now_seconds, clock.wall_diff_seconds
end

local function _try_get_now(wall_now_seconds)
  if type(wall_now_seconds) ~= "function" then
    return nil, false
  end
  local ok_now, now = pcall(wall_now_seconds)
  if not ok_now or not number_utils.is_numeric(now) then
    return nil, false
  end
  return now, true
end

local function _update_tick_state(state, now)
  local previous = state.tick_wall_now_seconds
  state.tick_wall_now_seconds = now
  return previous
end

local function _try_wall_diff(wall_diff_seconds, a, b)
  if type(wall_diff_seconds) ~= "function" then
    return nil, false
  end
  local ok_diff, diff = pcall(wall_diff_seconds, a, b)
  local normalized = _normalize_positive_dt(diff)
  if ok_diff and normalized ~= nil then
    return normalized, true, diff
  end
  return nil, false, diff
end

local function _try_raw_diff(a, b)
  local raw_diff = a - b
  local normalized = _normalize_positive_dt(raw_diff)
  if normalized ~= nil then
    return normalized, true, raw_diff
  end
  return nil, false, raw_diff
end

local function _try_resolve_wall_diff(wall_diff_seconds, now, previous)
  local diff_result, diff_ok, diff_raw = _try_wall_diff(wall_diff_seconds, now, previous)
  if diff_ok then
    return diff_result, "wall:diff", diff_raw
  end
  local reverse_result, reverse_ok, reverse_raw = _try_wall_diff(wall_diff_seconds, previous, now)
  if reverse_ok then
    return reverse_result, "wall:diff_reversed", reverse_raw
  end
  return nil, nil, diff_raw
end

local function _try_resolve_raw_diff(now, previous)
  local raw_result, raw_ok, raw_val = _try_raw_diff(now, previous)
  if raw_ok then
    return raw_result, "wall:raw_diff", raw_val
  end
  local raw_rev_result, raw_rev_ok, raw_rev_val = _try_raw_diff(previous, now)
  if raw_rev_ok then
    return raw_rev_result, "wall:raw_diff_reversed", raw_rev_val
  end
  return nil, nil, nil
end

local function _resolve_tick_fallback(state, fallback_seconds, reason)
  return fallback_seconds, reason, state and state.tick_wall_now_seconds or nil, nil, nil
end

local function _try_resolve_tick_diff(wall_diff_seconds, now, previous, fallback_seconds)
  if _is_integer_like_time(now) and _is_integer_like_time(previous) then
    return fallback_seconds, "fallback:coarse_wall_clock", now, previous, nil
  end

  local wall_result, wall_tag, wall_raw = _try_resolve_wall_diff(wall_diff_seconds, now, previous)
  if wall_result ~= nil then
    return wall_result, wall_tag, now, previous, wall_raw
  end

  local raw_result, raw_tag, raw_val = _try_resolve_raw_diff(now, previous)
  if raw_result ~= nil then
    return raw_result, raw_tag, now, previous, raw_val
  end

  return fallback_seconds, "fallback:diff_invalid", now, previous, wall_raw
end

local function _try_get_previous_tick(state, now)
  local previous = _update_tick_state(state, now)
  if not number_utils.is_numeric(previous) then
    return nil, "fallback:no_previous"
  end
  return previous, nil
end

tick_clock.resolve_fallback_tick_seconds = _resolve_fallback_tick_seconds

-- state 上时钟的 wall 函数对;缺任一返回 nil(调用方走 no_clock 兜底)。
local function _clock_wall_functions(state)
  local clock = _resolve_clock_from_state(state)
  local wall_now_seconds, wall_diff_seconds = _resolve_wall_functions(clock)
  if not wall_now_seconds or not wall_diff_seconds then
    return nil
  end
  return wall_now_seconds, wall_diff_seconds
end

function tick_clock.resolve_tick_seconds(state, fallback_seconds)
  if not state then
    return _resolve_tick_fallback(nil, fallback_seconds, "fallback:no_state")
  end

  local wall_now_seconds, wall_diff_seconds = _clock_wall_functions(state)
  if not wall_now_seconds then
    return _resolve_tick_fallback(state, fallback_seconds, "fallback:no_clock")
  end

  local now, ok_now = _try_get_now(wall_now_seconds)
  if not ok_now then
    return _resolve_tick_fallback(state, fallback_seconds, "fallback:now_invalid")
  end

  local previous, previous_err = _try_get_previous_tick(state, now)
  if previous_err then
    return fallback_seconds, previous_err, now, nil, nil
  end

  return _try_resolve_tick_diff(wall_diff_seconds, now, previous, fallback_seconds)
end

return tick_clock

--[[ mutate4lua-manifest
version=4
projectHash=90ad230af75be1dd
scope.0.id=chunk:src/turn/loop/tick_clock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=178
scope.0.semanticHash=6012b4f35fb557f8
scope.1.id=function:_resolve_fallback_tick_seconds
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=52ff0118cced1e5a
scope.2.id=function:_normalize_positive_dt
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=b4d1c32c8fd0d176
scope.3.id=function:_is_integer_like_time
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=33
scope.3.semanticHash=ff7871dd36afa9cc
scope.4.id=function:_resolve_clock_from_state
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=41
scope.4.semanticHash=220d4443e9ec7195
scope.5.id=function:_resolve_wall_functions
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=48
scope.5.semanticHash=6f7daa48c70ec2bd
scope.6.id=function:_try_get_now
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=59
scope.6.semanticHash=ef35c35825b8c98e
scope.7.id=function:_update_tick_state
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=65
scope.7.semanticHash=9d49d5cfd9ff2157
scope.8.id=function:_try_wall_diff
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=77
scope.8.semanticHash=afad00f746f09880
scope.9.id=function:_try_raw_diff
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=86
scope.9.semanticHash=6c681fb9e1f375d3
scope.10.id=function:_try_resolve_wall_diff
scope.10.kind=function
scope.10.startLine=88
scope.10.endLine=98
scope.10.semanticHash=6ec7876ac6ea4c29
scope.11.id=function:_try_resolve_raw_diff
scope.11.kind=function
scope.11.startLine=100
scope.11.endLine=110
scope.11.semanticHash=d9dadd5de6252c5d
scope.12.id=function:_resolve_tick_fallback
scope.12.kind=function
scope.12.startLine=112
scope.12.endLine=114
scope.12.semanticHash=5cc851b9fc4b8d4f
scope.13.id=function:_try_resolve_tick_diff
scope.13.kind=function
scope.13.startLine=116
scope.13.endLine=132
scope.13.semanticHash=225ed833dcf3e3d1
scope.14.id=function:_try_get_previous_tick
scope.14.kind=function
scope.14.startLine=134
scope.14.endLine=140
scope.14.semanticHash=97afaabbba410dc0
scope.15.id=function:_clock_wall_functions
scope.15.kind=function
scope.15.startLine=145
scope.15.endLine=152
scope.15.semanticHash=9da490b1c1b95147
scope.16.id=function:tick_clock.resolve_tick_seconds
scope.16.kind=function
scope.16.startLine=154
scope.16.endLine=175
scope.16.semanticHash=1da0a968bb087621
]]
