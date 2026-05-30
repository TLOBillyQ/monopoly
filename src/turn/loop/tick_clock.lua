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

function tick_clock.resolve_tick_seconds(state, fallback_seconds)
  if not state then
    return _resolve_tick_fallback(nil, fallback_seconds, "fallback:no_state")
  end

  local clock = _resolve_clock_from_state(state)
  local wall_now_seconds, wall_diff_seconds = _resolve_wall_functions(clock)
  if not wall_now_seconds or not wall_diff_seconds then
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
version=2
projectHash=da81b41d36172209
scope.0.id=chunk:src/turn/loop/tick_clock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=169
scope.0.semanticHash=23564e1b23d4ecea
scope.1.id=function:_resolve_fallback_tick_seconds:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=80162c462230e6f8
scope.2.id=function:_normalize_positive_dt:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=bc560e59b656036b
scope.3.id=function:_is_integer_like_time:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=33
scope.3.semanticHash=9b2cdfa31966bfaf
scope.4.id=function:_resolve_clock_from_state:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=41
scope.4.semanticHash=3f598709a7f72795
scope.5.id=function:_resolve_wall_functions:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=48
scope.5.semanticHash=541a6afde0952642
scope.6.id=function:_try_get_now:50
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=59
scope.6.semanticHash=ff98ca0def63edd0
scope.7.id=function:_update_tick_state:61
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=65
scope.7.semanticHash=49e8fbcab1a608ab
scope.8.id=function:_try_wall_diff:67
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=77
scope.8.semanticHash=6ed1887d31fbe3d1
scope.9.id=function:_try_raw_diff:79
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=86
scope.9.semanticHash=fb00c3047e5e8051
scope.10.id=function:_try_resolve_wall_diff:88
scope.10.kind=function
scope.10.startLine=88
scope.10.endLine=98
scope.10.semanticHash=bbf6adb5fe6bfb91
scope.11.id=function:_try_resolve_raw_diff:100
scope.11.kind=function
scope.11.startLine=100
scope.11.endLine=110
scope.11.semanticHash=b9da8bb974c2312e
scope.12.id=function:_resolve_tick_fallback:112
scope.12.kind=function
scope.12.startLine=112
scope.12.endLine=114
scope.12.semanticHash=9084cb5b3c2a4800
scope.13.id=function:_try_resolve_tick_diff:116
scope.13.kind=function
scope.13.startLine=116
scope.13.endLine=132
scope.13.semanticHash=d179dfdf92992b50
scope.14.id=function:_try_get_previous_tick:134
scope.14.kind=function
scope.14.startLine=134
scope.14.endLine=140
scope.14.semanticHash=098f981ef4871493
scope.15.id=function:tick_clock.resolve_tick_seconds:144
scope.15.kind=function
scope.15.startLine=144
scope.15.endLine=166
scope.15.semanticHash=73ffd008fc1ae5ef
]]
