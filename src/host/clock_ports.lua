-- 时钟端口默认实现(自 default_ports.lua 拆分,行为保持):wall/cpu 时刻与差值
-- 的宿主 API 适配,经 runtime_context 取当前 env 的 GameAPI 时间戳方法。
local number_utils = require("src.foundation.number")

local clock_ports = {}

local function _current_env(runtime_context)
  local ctx = runtime_context.current and runtime_context.current() or nil
  return ctx and ctx.env or nil
end

local function _current_game_api(runtime_context)
  local env = _current_env(runtime_context)
  return env and env["Game" .. "API"] or nil
end

local function _try_timestamp_from_api(game_api)
  if game_api and type(game_api.get_timestamp) == "function" then
    local ok, ts = pcall(game_api.get_timestamp)
    if ok and number_utils.is_numeric(ts) then
      return ts
    end
  end
  return nil
end

local function _api_now_seconds(runtime_context)
  local ts = _try_timestamp_from_api(_current_game_api(runtime_context))
  return ts or 0
end

local function _part_fn(game_api, fn_name)
  local fn = game_api[fn_name]
  if type(fn) ~= "function" then
    return nil
  end
  return fn
end

local function _numeric_part(fn, ts_value)
  local ok, val = pcall(fn, ts_value)
  if not ok or not number_utils.is_numeric(val) then
    return nil
  end
  return number_utils.to_integer(val)
end

local function _safe_part(game_api, fn_name, ts)
  local fn = _part_fn(game_api, fn_name)
  if fn == nil then
    return nil
  end
  return _numeric_part(fn, ts)
end

local function _parts_complete(h, m, s)
  return h ~= nil and m ~= nil and s ~= nil
end

local function _wall_now_hms(runtime_context)
  local game_api = _current_game_api(runtime_context)
  if game_api == nil then
    return ""
  end
  local ts = _try_timestamp_from_api(game_api)
  if ts == nil then
    return ""
  end
  local h = _safe_part(game_api, "get_hour", ts)
  local m = _safe_part(game_api, "get_minute", ts)
  local s = _safe_part(game_api, "get_second", ts)
  if not _parts_complete(h, m, s) then
    return ""
  end
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function _diff_ready(game_api, t1, t2)
  return game_api ~= nil and type(game_api.get_timestamp_diff) == "function"
    and number_utils.is_numeric(t1) and number_utils.is_numeric(t2)
end

local function _safe_timestamp_diff(game_api, t1, t2)
  local ok, diff = pcall(game_api.get_timestamp_diff, t1, t2)
  if ok and number_utils.is_numeric(diff) then
    return diff
  end
  return nil
end

local function _timestamp_diff(game_api, t1, t2)
  if _diff_ready(game_api, t1, t2) then
    return _safe_timestamp_diff(game_api, t1, t2)
  end
  return nil
end

function clock_ports.install(defaults, runtime_context)
  defaults.wall_now_seconds = function()
    return _api_now_seconds(runtime_context)
  end

  defaults.wall_now_hms = function()
    return _wall_now_hms(runtime_context)
  end

  defaults.wall_diff_seconds = function(timestamp_1, timestamp_2)
    return _timestamp_diff(_current_game_api(runtime_context), timestamp_1, timestamp_2)
      or number_utils.diff_or_zero(timestamp_1, timestamp_2)
  end

  defaults.cpu_now_seconds = function()
    return _api_now_seconds(runtime_context)
  end

  defaults.cpu_diff_seconds = number_utils.diff_or_zero
end

return clock_ports

--[[ mutate4lua-manifest
version=4
projectHash=7c9b612638069ad2
scope.0.id=chunk:src/host/clock_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=120
scope.0.semanticHash=8ade8800e7057362
scope.1.id=function:_current_env
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=10
scope.1.semanticHash=d08d43958f5bffa4
scope.2.id=function:_current_game_api
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=c1a993e537c4d1c6
scope.3.id=function:_try_timestamp_from_api
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=25
scope.3.semanticHash=2228b7b1c710e316
scope.4.id=function:_api_now_seconds
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=30
scope.4.semanticHash=41f5270071c1757d
scope.5.id=function:_part_fn
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=38
scope.5.semanticHash=e901577b9701b293
scope.6.id=function:_numeric_part
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=46
scope.6.semanticHash=50b53a90550cd59e
scope.7.id=function:_safe_part
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=54
scope.7.semanticHash=cc53fe48910a739f
scope.8.id=function:_parts_complete
scope.8.kind=function
scope.8.startLine=56
scope.8.endLine=58
scope.8.semanticHash=342b68d7fd51b713
scope.9.id=function:_wall_now_hms
scope.9.kind=function
scope.9.startLine=60
scope.9.endLine=76
scope.9.semanticHash=82909e66259b8503
scope.10.id=function:_diff_ready
scope.10.kind=function
scope.10.startLine=78
scope.10.endLine=81
scope.10.semanticHash=b26ac7cada5a86e2
scope.11.id=function:_safe_timestamp_diff
scope.11.kind=function
scope.11.startLine=83
scope.11.endLine=89
scope.11.semanticHash=fb327aaa37b8dad9
scope.12.id=function:_timestamp_diff
scope.12.kind=function
scope.12.startLine=91
scope.12.endLine=96
scope.12.semanticHash=41d4906cc1807bcc
scope.13.id=function:clock_ports.install
scope.13.kind=function
scope.13.startLine=98
scope.13.endLine=117
scope.13.semanticHash=ff4e6b89eef42c65
scope.14.id=function:defaults.wall_now_seconds
scope.14.kind=function
scope.14.startLine=99
scope.14.endLine=101
scope.14.semanticHash=7bbf31ab6751de78
scope.15.id=function:defaults.wall_now_hms
scope.15.kind=function
scope.15.startLine=103
scope.15.endLine=105
scope.15.semanticHash=7bbf31ab6751de78
scope.16.id=function:defaults.wall_diff_seconds
scope.16.kind=function
scope.16.startLine=107
scope.16.endLine=110
scope.16.semanticHash=96a45408d4341a66
scope.17.id=function:defaults.cpu_now_seconds
scope.17.kind=function
scope.17.startLine=112
scope.17.endLine=114
scope.17.semanticHash=7bbf31ab6751de78
]]
