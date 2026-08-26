local tip_queue = require("src.foundation.tips")

local _stringify_parts = {}

local function _stringify(...)
  local count = select("#", ...)
  for i = 1, count do
    _stringify_parts[i] = tostring(select(i, ...))
  end
  for i = count + 1, #_stringify_parts do
    _stringify_parts[i] = nil
  end
  return table.concat(_stringify_parts, " ")
end

-- 无时间前缀即不带前缀,也不留前导空格(契约)。宿主可换 time_formatter,返回空串
-- 或 nil 都算「没有前缀」。level / text 由唯一生产者 _create_entry 保证非 nil。
local function _format_entry(entry)
  local time_text = entry.time_text or ""
  if time_text ~= "" then
    return time_text .. " [" .. entry.level .. "] " .. entry.text
  end
  return "[" .. entry.level .. "] " .. entry.text
end

local function _unlimited(opts)
  return opts ~= nil and opts.unlimited == true
end

local function _has_info_limit(state)
  local limit = state.info_per_turn_limit
  local provider = state.info_turn_provider
  return limit ~= nil and limit > 0 and provider ~= nil
end

local function _reset_on_turn_change(state, turn)
  if state.info_turn ~= turn then
    state.info_turn = turn
    state.info_turn_count = 0
  end
end

local function _check_info_turn_limit(state, opts)
  if _unlimited(opts) then
    return false
  end
  if not _has_info_limit(state) then
    return false
  end
  local turn = state.info_turn_provider()
  if turn == nil then
    return false
  end
  _reset_on_turn_change(state, turn)
  if state.info_turn_count >= state.info_per_turn_limit then
    return true
  end
  state.info_turn_count = state.info_turn_count + 1
  return false
end

local function _create_entry(state, level, text, ui)
  local timestamp = state.timestamp_provider()
  local time_text = state.time_formatter(timestamp)
  return {
    level = level,
    text = text,
    ui = ui,
    timestamp = timestamp,
    time_text = time_text,
  }
end

local logger = {
  info_per_turn_limit = nil,
  info_turn_provider = nil,
  info_turn = nil,
  info_turn_count = 0,
  timestamp_provider = function()
    return 0
  end,
  time_formatter = function(timestamp)
    return tostring(timestamp)
  end,
  anim_debug_enabled_provider = nil,
  test_mode = false,
}

local function _set_timestamp_provider(provider)
  logger.timestamp_provider = provider
end

-- 时间前缀的渲染由宿主决定:formatter 返回空串即不带前缀(见 _format_entry)。
-- 这是公开接缝——调用方不该直接改 logger.time_formatter 字段。
function logger.set_time_formatter(formatter)
  assert(type(formatter) == "function", "time formatter must be function")
  logger.time_formatter = formatter
end

local _set_time_formatter = logger.set_time_formatter

function logger.reset_time_runtime()
  _set_timestamp_provider(function()
    return 0
  end)
  _set_time_formatter(function(timestamp)
    return tostring(timestamp)
  end)
end

function logger.set_anim_debug_enabled_provider(provider)
  if provider ~= nil then
    assert(type(provider) == "function", "anim debug provider must be function or nil")
  end
  logger.anim_debug_enabled_provider = provider
end

function logger.set_test_mode(enabled)
  logger.test_mode = enabled == true
  tip_queue.configure_runtime({
    test_mode = logger.test_mode,
  })
end

function logger.is_test_mode()
  return logger.test_mode == true
end

function logger.is_anim_debug_enabled()
  local provider = logger.anim_debug_enabled_provider
  if type(provider) ~= "function" then
    return false
  end
  local ok, result = pcall(provider)
  if not ok then
    return false
  end
  return result == true
end

function logger.configure_game_time(game_api)
  assert(game_api ~= nil, "missing game api")
  _set_timestamp_provider(function()
    return game_api.get_timestamp()
  end)

  local function _pad2(value)
    if value < 10 then
      return "0" .. tostring(value)
    end
    return tostring(value)
  end

  _set_time_formatter(function(timestamp)
    assert(timestamp ~= nil, "missing timestamp")
    local hour = game_api.get_hour(timestamp)
    local minute = game_api.get_minute(timestamp)
    local second = game_api.get_second(timestamp)
    return _pad2(hour) .. ":" .. _pad2(minute) .. ":" .. _pad2(second)
  end)
end

-- 每回合限流的计数只对「当前 limit + provider」这套配置有意义：换配置（新开
-- 一局会重新绑定 provider）必须作废旧账本，否则上一局用尽的配额会误伤新一局
-- 同回合号的首批 info。清掉 info_turn 就够了——下次检查发现回合号与之不符，
-- 会顺手把计数归零（见 _check_info_turn_limit）。
local function _reset_info_turn_accounting()
  logger.info_turn = nil
end

function logger.set_info_per_turn_limit(limit)
  logger.info_per_turn_limit = limit
  _reset_info_turn_accounting()
end

function logger.set_info_turn_provider(provider)
  logger.info_turn_provider = provider
  _reset_info_turn_accounting()
end

function logger.set_ui_sink(sink)
  logger.ui_sink = sink
end

-- entry.ui 是唯一上屏凭证(#522):仅 opts.ui == true 时置 true,其余保持 nil,
-- 让 sink 的「entry.ui == true 才上屏」判定与调用点显式声明一一对应。
local function _ui_flag(opts)
  if opts ~= nil and opts.ui == true then
    return true
  end
  return nil
end

local function _push(state, level, opts, ...)
  if level == "info" and _check_info_turn_limit(state, opts) then
    return
  end
  local text = _stringify(...)
  local entry = _create_entry(state, level, text, _ui_flag(opts))
  if state.ui_sink then
    state.ui_sink(entry)
  end
  if type(print) == "function" then
    pcall(print, _format_entry(entry))
  end
end

local function _level_logger(level)
  return function(...)
    _push(logger, level, nil, ...)
  end
end

logger.info = _level_logger("info")
logger.warn = _level_logger("warn")

local _warn_ui_opts = { ui = true }

-- #522:warn 默认只进 log.txt(print),ui_sink 不再无条件上屏——116 个 warn
-- 调用点逐条盘点均为开发者留痕,玩家可见的规则提示走 tip_queue 专用通道。
-- 确需上屏的 warn 用 warn_ui 显式声明;上屏白名单 = 全部 warn_ui 调用点
-- (grep 可得,2026-08-20 盘点时为空)。
function logger.warn_ui(...)
  _push(logger, "warn", _warn_ui_opts, ...)
end

local _info_unlimited_opts = { unlimited = true }

function logger.info_unlimited(...)
  _push(logger, "info", _info_unlimited_opts, ...)
end

function logger.log_once(sink, level, key, ...)
  assert(type(sink) == "table", "missing dedupe sink")
  if sink[key] then
    return false
  end
  sink[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
  return true
end

return logger

--[[ mutate4lua-manifest
version=4
projectHash=06170f5856daac70
scope.0.id=chunk:src/foundation/log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=248
scope.0.semanticHash=587760b754fe30f9
scope.1.id=function:_stringify
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=14
scope.1.semanticHash=9e8fd4a336334eec
scope.2.id=function:_format_entry
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=24
scope.2.semanticHash=0481a92bf7dea668
scope.3.id=function:_unlimited
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=be8994585243633b
scope.4.id=function:_has_info_limit
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=34
scope.4.semanticHash=3b3cd9f7054af289
scope.5.id=function:_reset_on_turn_change
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=41
scope.5.semanticHash=41a14a39055e1621
scope.6.id=function:_check_info_turn_limit
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=60
scope.6.semanticHash=86a7dd60d2454dcf
scope.7.id=function:_create_entry
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=72
scope.7.semanticHash=132c42a172290743
scope.8.id=function:<anonymous>
scope.8.kind=function
scope.8.startLine=79
scope.8.endLine=81
scope.8.semanticHash=f27a380acaa19c35
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=84
scope.9.semanticHash=f1ce1850b7232305
scope.10.id=function:_set_timestamp_provider
scope.10.kind=function
scope.10.startLine=89
scope.10.endLine=91
scope.10.semanticHash=a9d82726f0169db1
scope.11.id=function:logger.set_time_formatter
scope.11.kind=function
scope.11.startLine=95
scope.11.endLine=98
scope.11.semanticHash=c0a0673e5c2ec977
scope.12.id=function:logger.reset_time_runtime
scope.12.kind=function
scope.12.startLine=102
scope.12.endLine=109
scope.12.semanticHash=aa03acbfd71e69d8
scope.13.id=function:<anonymous>#3
scope.13.kind=function
scope.13.startLine=103
scope.13.endLine=105
scope.13.semanticHash=f27a380acaa19c35
scope.14.id=function:<anonymous>#4
scope.14.kind=function
scope.14.startLine=106
scope.14.endLine=108
scope.14.semanticHash=f1ce1850b7232305
scope.15.id=function:logger.set_anim_debug_enabled_provider
scope.15.kind=function
scope.15.startLine=111
scope.15.endLine=116
scope.15.semanticHash=2063d3275bf66095
scope.16.id=function:logger.set_test_mode
scope.16.kind=function
scope.16.startLine=118
scope.16.endLine=123
scope.16.semanticHash=3435af8c665b4ffb
scope.17.id=function:logger.is_test_mode
scope.17.kind=function
scope.17.startLine=125
scope.17.endLine=127
scope.17.semanticHash=69ebbd4c820b6b33
scope.18.id=function:logger.is_anim_debug_enabled
scope.18.kind=function
scope.18.startLine=129
scope.18.endLine=139
scope.18.semanticHash=f5db1788ab1a204e
scope.19.id=function:logger.configure_game_time
scope.19.kind=function
scope.19.startLine=141
scope.19.endLine=161
scope.19.semanticHash=1c6b8e13a6dfec66
scope.20.id=function:<anonymous>#5
scope.20.kind=function
scope.20.startLine=143
scope.20.endLine=145
scope.20.semanticHash=04a3b0c01baa0aa1
scope.21.id=function:_pad2
scope.21.kind=function
scope.21.startLine=147
scope.21.endLine=152
scope.21.semanticHash=c44fadfbc23e4925
scope.22.id=function:<anonymous>#6
scope.22.kind=function
scope.22.startLine=154
scope.22.endLine=160
scope.22.semanticHash=408adc32bef1c690
scope.23.id=function:_reset_info_turn_accounting
scope.23.kind=function
scope.23.startLine=167
scope.23.endLine=169
scope.23.semanticHash=de73855b9bd40abb
scope.24.id=function:logger.set_info_per_turn_limit
scope.24.kind=function
scope.24.startLine=171
scope.24.endLine=174
scope.24.semanticHash=72a19e8bb45cddc5
scope.25.id=function:logger.set_info_turn_provider
scope.25.kind=function
scope.25.startLine=176
scope.25.endLine=179
scope.25.semanticHash=72a19e8bb45cddc5
scope.26.id=function:logger.set_ui_sink
scope.26.kind=function
scope.26.startLine=181
scope.26.endLine=183
scope.26.semanticHash=a9d82726f0169db1
scope.27.id=function:_ui_flag
scope.27.kind=function
scope.27.startLine=187
scope.27.endLine=192
scope.27.semanticHash=1ac420002f9e6b82
scope.28.id=function:_push
scope.28.kind=function
scope.28.startLine=194
scope.28.endLine=206
scope.28.semanticHash=98927a563ce13194
scope.29.id=function:_level_logger
scope.29.kind=function
scope.29.startLine=208
scope.29.endLine=212
scope.29.semanticHash=1943d6b43444bb75
scope.30.id=function:<anonymous>#7
scope.30.kind=function
scope.30.startLine=209
scope.30.endLine=211
scope.30.semanticHash=a06232deaeff42a0
scope.31.id=function:logger.warn_ui
scope.31.kind=function
scope.31.startLine=223
scope.31.endLine=225
scope.31.semanticHash=9d84030e83eece6c
scope.32.id=function:logger.info_unlimited
scope.32.kind=function
scope.32.startLine=229
scope.32.endLine=231
scope.32.semanticHash=9d84030e83eece6c
scope.33.id=function:logger.log_once
scope.33.kind=function
scope.33.startLine=233
scope.33.endLine=245
scope.33.semanticHash=26625c3d552b29ab
]]
