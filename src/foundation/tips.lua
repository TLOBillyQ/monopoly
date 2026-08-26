local tip_util = require("src.foundation.tip_util")
local tip_runtime = require("src.foundation.tip_runtime")

local function _warn(...)
  local ok, log = pcall(require, "src.foundation.log")
  if ok and type(log) == "table" and type(log.warn) == "function" then
    log.warn(...)
  end
end

-- 队列按「投给谁」分区串行:不带 role_id 的提示(事件流等)住全局 scope,行为与
-- 分区前完全一致;带 role_id 的私人提示(如道具槽拒绝)各自独立排队。
-- 分区前所有人共用一条串行队列,甲的 2 秒提示会把乙屏幕上的提示一起压住,
-- 主观就是「点了没反应」——而两人根本不在同一块屏幕上,本就不该互相排队。
-- 全局 scope 的字段直接挂在 tip_queue 上(pending / active_tip),既有读者不变。
local tip_queue = {
  pending = {},
  active_tip = nil,
  role_scopes = {},
  runtime = {
    presenter = nil,
    scheduler = nil,
    test_mode = false,
    event_tip_fast_backlog_threshold = 2,
    event_tip_fast_seconds = 0.5,
  },
  epoch = 0,
}

local function _backlog_threshold()
  return tip_queue.runtime.event_tip_fast_backlog_threshold or 2
end

local function _fast_seconds()
  return tip_queue.runtime.event_tip_fast_seconds or 0.5
end

local function _scope(role_id)
  return tip_util.resolve_scope(tip_queue, role_id)
end

local function _each_scope(fn)
  return tip_util.each_scope(tip_queue, fn)
end

local function _apply_backlog_acceleration(scope, duration)
  local backlog = #scope.pending
  if backlog < _backlog_threshold() then
    return duration
  end
  local fast = _fast_seconds()
  if fast < duration then
    return fast
  end
  return duration
end

local function _normalize_duration(duration)
  return tip_util.normalize_duration(duration)
end

local function _normalize_intent(intent)
  return tip_util.normalize_intent(intent, _normalize_duration)
end

local function _pending_has_key(pending, dedupe_key)
  for i = 1, #pending do
    if pending[i].dedupe_key == dedupe_key then
      return true
    end
  end
  return false
end

local function _has_matching_dedupe_key(scope, dedupe_key)
  if dedupe_key == nil then
    return false
  end
  local active_tip = scope.active_tip
  if active_tip ~= nil and active_tip.dedupe_key == dedupe_key then
    return true
  end
  return _pending_has_key(scope.pending, dedupe_key)
end

local function _present_tip(tip)
  local presenter = tip_queue.runtime.presenter
  if type(presenter) ~= "function" then
    -- warned 标记住 runtime 表（tip_runtime 在换上新 presenter 时负责复位），
    -- 避免模块级 local 经 ref 在 configure 间 round-trip。
    if not tip_queue.runtime.presenter_warned then
      tip_queue.runtime.presenter_warned = true
      _warn("[tip_queue]", "presenter not registered - tips will be dropped until configure_runtime is called")
    end
    return false
  end
  local ok, err = pcall(presenter, tip.text, tip.duration, tip)
  if not ok then
    _warn("[tip_queue]", "presenter raised error:", tostring(err), "| text:", tostring(tip.text))
  end
  return ok
end

local function _immediate_release(scheduler, release_fn)
  if type(scheduler) ~= "function" then
    release_fn()
    return true
  end
  return false
end

-- 包装 release_fn 并暴露「是否已被调用」的查询,调度回调与原语义一致。
local function _wrapped_release(release_fn)
  local invoked = false
  return function()
    return invoked
  end, function()
    invoked = true
    release_fn()
  end
end

local function _invoked_ok(ok, is_invoked)
  return ok ~= nil and is_invoked()
end

local function _handled_ok(ok, handled)
  return ok ~= nil and handled == true
end

local function _test_mode_release(release_fn)
  if tip_queue.runtime.test_mode == true then
    release_fn()
  end
end

local function _schedule_release(delay, release_fn)
  local scheduler = tip_queue.runtime.scheduler
  if _immediate_release(scheduler, release_fn) then
    return
  end

  local is_invoked, _wrapped = _wrapped_release(release_fn)
  local ok, handled = pcall(scheduler, delay, _wrapped)
  if _invoked_ok(ok, is_invoked) then
    return
  end
  if _handled_ok(ok, handled) then
    _test_mode_release(release_fn)
    return
  end
  release_fn()
end

local function _effective_duration(scope, tip)
  return _apply_backlog_acceleration(scope, tip.duration)
end

local _activate_next_pending

local function _release_tip(epoch, scope, tip)
  if tip_queue.epoch ~= epoch then
    return
  end
  if scope.active_tip ~= tip then
    return
  end
  scope.active_tip = nil
  _activate_next_pending(scope)
end

function _activate_next_pending(scope)
  local pending = scope.pending
  if #pending <= 0 then
    return
  end
  local next_tip = table.remove(pending, 1)
  scope.active_tip = next_tip
  local current_epoch = tip_queue.epoch
  _present_tip(next_tip)
  _schedule_release(_effective_duration(scope, next_tip), function()
    _release_tip(current_epoch, scope, next_tip)
  end)
end

local function _dispatch_next_tip(scope)
  if scope.active_tip ~= nil then
    return
  end
  _activate_next_pending(scope)
end

function tip_queue.configure_runtime(adapter)
  -- 私有的 _dispatch_next_tip 作显式参数传给 tip_runtime，不挂公开表
  -- （挂在 tip_queue 上任何持有者可覆盖，会静默破坏队列调度）。
  tip_runtime.configure(tip_queue, adapter, _dispatch_next_tip)
end

function tip_queue.enqueue(intent)
  local tip = _normalize_intent(intent)
  if tip == nil then
    return false
  end
  local scope = _scope(tip.role_id)
  if _has_matching_dedupe_key(scope, tip.dedupe_key) then
    return false
  end
  local pending = scope.pending
  pending[#pending + 1] = tip
  _dispatch_next_tip(scope)
  return true
end

-- inter_turn 闸跨全部 scope:任何一块屏幕上还压着阻塞提示,回合就不该翻页。
function tip_queue.has_blocking_pending(phase_name)
  if phase_name ~= "inter_turn" then
    return false
  end
  return _each_scope(function(scope)
    local active_tip = scope.active_tip
    if active_tip ~= nil and active_tip.blocks_inter_turn == true then
      return true
    end
    local pending = scope.pending
    for i = 1, #pending do
      if pending[i].blocks_inter_turn == true then
        return true
      end
    end
    return nil
  end) == true
end

function tip_queue.clear()
  tip_queue.pending = {}
  tip_queue.active_tip = nil
  tip_queue.role_scopes = {}
  tip_queue.epoch = tip_queue.epoch + 1
end

local function _pending_count()
  local total = 0
  _each_scope(function(scope)
    total = total + #scope.pending
    return nil
  end)
  return total
end

function tip_queue.snapshot()
  return {
    has_presenter = type(tip_queue.runtime.presenter) == "function",
    has_scheduler = type(tip_queue.runtime.scheduler) == "function",
    pending_count = _pending_count(),
    active_text = tip_queue.active_tip and tip_queue.active_tip.text or nil,
    epoch = tip_queue.epoch,
    test_mode = tip_queue.runtime.test_mode,
  }
end

return tip_queue

--[[ mutate4lua-manifest
version=4
projectHash=8882ecdb057d0d1b
scope.0.id=chunk:src/foundation/tips.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=262
scope.0.semanticHash=388354ebba295594
scope.1.id=function:_warn
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=9
scope.1.semanticHash=3a7801417fa20a40
scope.2.id=function:_backlog_threshold
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=32
scope.2.semanticHash=8e02aeea11131ec4
scope.3.id=function:_fast_seconds
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=36
scope.3.semanticHash=8e02aeea11131ec4
scope.4.id=function:_scope
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=40
scope.4.semanticHash=e504e513aab7d79c
scope.5.id=function:_each_scope
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=44
scope.5.semanticHash=e504e513aab7d79c
scope.6.id=function:_apply_backlog_acceleration
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=56
scope.6.semanticHash=37246bef6616f27f
scope.7.id=function:_normalize_duration
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=60
scope.7.semanticHash=f1ce1850b7232305
scope.8.id=function:_normalize_intent
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=64
scope.8.semanticHash=e504e513aab7d79c
scope.9.id=function:_pending_has_key
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=73
scope.9.semanticHash=8929283dcce0ca9c
scope.10.id=function:_has_matching_dedupe_key
scope.10.kind=function
scope.10.startLine=75
scope.10.endLine=84
scope.10.semanticHash=1901a09450321e70
scope.11.id=function:_present_tip
scope.11.kind=function
scope.11.startLine=86
scope.11.endLine=102
scope.11.semanticHash=da3a6272e4bd4169
scope.12.id=function:_immediate_release
scope.12.kind=function
scope.12.startLine=104
scope.12.endLine=110
scope.12.semanticHash=803312e24844114c
scope.13.id=function:_wrapped_release
scope.13.kind=function
scope.13.startLine=113
scope.13.endLine=121
scope.13.semanticHash=aff8a86b964eb659
scope.14.id=function:<anonymous>
scope.14.kind=function
scope.14.startLine=115
scope.14.endLine=117
scope.14.semanticHash=1136505bd37c301e
scope.15.id=function:<anonymous>#2
scope.15.kind=function
scope.15.startLine=117
scope.15.endLine=120
scope.15.semanticHash=940ea29a91aaa65d
scope.16.id=function:_invoked_ok
scope.16.kind=function
scope.16.startLine=123
scope.16.endLine=125
scope.16.semanticHash=8b26ad883172a846
scope.17.id=function:_handled_ok
scope.17.kind=function
scope.17.startLine=127
scope.17.endLine=129
scope.17.semanticHash=064bdcb070d72209
scope.18.id=function:_test_mode_release
scope.18.kind=function
scope.18.startLine=131
scope.18.endLine=135
scope.18.semanticHash=0c117445104e6287
scope.19.id=function:_schedule_release
scope.19.kind=function
scope.19.startLine=137
scope.19.endLine=153
scope.19.semanticHash=c15af8f330c859bd
scope.20.id=function:_effective_duration
scope.20.kind=function
scope.20.startLine=155
scope.20.endLine=157
scope.20.semanticHash=e2837bec134be058
scope.21.id=function:_release_tip
scope.21.kind=function
scope.21.startLine=161
scope.21.endLine=170
scope.21.semanticHash=3e857bd0241fb94f
scope.22.id=function:_activate_next_pending
scope.22.kind=function
scope.22.startLine=172
scope.22.endLine=184
scope.22.semanticHash=48dca5834b391d31
scope.23.id=function:<anonymous>#3
scope.23.kind=function
scope.23.startLine=181
scope.23.endLine=183
scope.23.semanticHash=4ac65c65acb92f3b
scope.24.id=function:_dispatch_next_tip
scope.24.kind=function
scope.24.startLine=186
scope.24.endLine=191
scope.24.semanticHash=5955abbfd1a3434a
scope.25.id=function:tip_queue.configure_runtime
scope.25.kind=function
scope.25.startLine=193
scope.25.endLine=197
scope.25.semanticHash=11e97ffd44326f60
scope.26.id=function:tip_queue.enqueue
scope.26.kind=function
scope.26.startLine=199
scope.26.endLine=212
scope.26.semanticHash=e3e0336139c42360
scope.27.id=function:tip_queue.has_blocking_pending
scope.27.kind=function
scope.27.startLine=215
scope.27.endLine=232
scope.27.semanticHash=efd85b4ab36128ab
scope.28.id=function:<anonymous>#4
scope.28.kind=function
scope.28.startLine=219
scope.28.endLine=231
scope.28.semanticHash=0bac1174cabc7b28
scope.29.id=function:tip_queue.clear
scope.29.kind=function
scope.29.startLine=234
scope.29.endLine=239
scope.29.semanticHash=c9d41618c6075b26
scope.30.id=function:_pending_count
scope.30.kind=function
scope.30.startLine=241
scope.30.endLine=248
scope.30.semanticHash=83bb712d29c0a4c7
scope.31.id=function:<anonymous>#5
scope.31.kind=function
scope.31.startLine=243
scope.31.endLine=246
scope.31.semanticHash=250fd3dd97373413
scope.32.id=function:tip_queue.snapshot
scope.32.kind=function
scope.32.startLine=250
scope.32.endLine=259
scope.32.semanticHash=7a2bf5cf3678f6e0
]]
