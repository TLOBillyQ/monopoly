local number_utils = require("src.foundation.number")

local _presenter_warned = false

local function _warn(...)
  local ok, log = pcall(require, "src.foundation.log")
  if ok and type(log) == "table" and type(log.warn) == "function" then
    log.warn(...)
  end
end

local tip_queue = {
  pending = {},
  active_tip = nil,
  runtime = {
    presenter = nil,
    scheduler = nil,
    test_mode = false,
    event_tip_fast_backlog_threshold = 2,
    event_tip_fast_seconds = 0.5,
  },
  epoch = 0,
}

local function _normalize_duration(duration)
  if number_utils.is_numeric(duration) and duration > 0 then
    return duration
  end
  return 2.0
end

local function _backlog_threshold()
  return tip_queue.runtime.event_tip_fast_backlog_threshold or 2
end

local function _fast_seconds()
  return tip_queue.runtime.event_tip_fast_seconds or 0.5
end

local function _apply_backlog_acceleration(duration)
  local backlog = #tip_queue.pending
  if backlog < _backlog_threshold() then
    return duration
  end
  local fast = _fast_seconds()
  if fast < duration then
    return fast
  end
  return duration
end

local function _normalize_text(text)
  if text == nil then
    return nil
  end
  local ok, value = pcall(tostring, text)
  if not ok then
    return nil
  end
  return value
end

local function _normalize_intent(intent)
  if type(intent) ~= "table" then
    return nil
  end

  local text = _normalize_text(intent.text)
  if text == nil then
    return nil
  end

  return {
    text = text,
    duration = _normalize_duration(intent.duration),
    dedupe_key = intent.dedupe_key,
    blocks_inter_turn = intent.blocks_inter_turn == true,
    source = intent.source,
    chain_key = intent.chain_key,
  }
end

local function _has_matching_dedupe_key(dedupe_key)
  if dedupe_key == nil then
    return false
  end
  local active_tip = tip_queue.active_tip
  if active_tip ~= nil and active_tip.dedupe_key == dedupe_key then
    return true
  end
  local pending = tip_queue.pending
  for i = 1, #pending do
    if pending[i].dedupe_key == dedupe_key then
      return true
    end
  end
  return false
end

local function _present_tip(tip)
  local presenter = tip_queue.runtime.presenter
  if type(presenter) ~= "function" then
    if not _presenter_warned then
      _presenter_warned = true
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

local function _schedule_release(delay, release_fn)
  local scheduler = tip_queue.runtime.scheduler
  if type(scheduler) ~= "function" then
    release_fn()
    return
  end

  local invoked = false
  local function _wrapped()
    invoked = true
    release_fn()
  end

  local ok, handled = pcall(scheduler, delay, _wrapped)
  if ok and invoked then
    return
  end
  if ok and handled == true then
    if tip_queue.runtime.test_mode == true then
      release_fn()
    end
    return
  end
  release_fn()
end

local function _effective_duration(tip)
  return _apply_backlog_acceleration(tip.duration)
end

local _activate_next_pending

local function _release_tip(epoch, tip)
  if tip_queue.epoch ~= epoch then
    return
  end
  if tip_queue.active_tip ~= tip then
    return
  end
  tip_queue.active_tip = nil
  _activate_next_pending()
end

function _activate_next_pending()
  local pending = tip_queue.pending
  if #pending <= 0 then
    return
  end
  local next_tip = table.remove(pending, 1)
  tip_queue.active_tip = next_tip
  local current_epoch = tip_queue.epoch
  _present_tip(next_tip)
  _schedule_release(_effective_duration(next_tip), function()
    _release_tip(current_epoch, next_tip)
  end)
end

local function _dispatch_next_tip()
  if tip_queue.active_tip ~= nil then
    return
  end
  _activate_next_pending()
end

local function _try_set_runtime_field(adapter, field, target_key, error_msg, reset_fn)
  local fn = adapter[field]
  if fn == nil then return end
  assert(type(fn) == "function", error_msg)
  tip_queue.runtime[target_key] = fn
  if reset_fn then reset_fn() end
end

local function _try_set_presenter_field(adapter, field)
  _try_set_runtime_field(adapter, field, "presenter",
    "tip presenter must be function or nil",
    function() _presenter_warned = false end)
end

local function _try_set_scheduler_field(adapter, field)
  _try_set_runtime_field(adapter, field, "scheduler",
    "tip scheduler must be function or nil")
end

local function _apply_test_mode(adapter)
  if adapter.test_mode ~= nil then
    tip_queue.runtime.test_mode = adapter.test_mode == true
  end
end

local function _apply_numeric_runtime_field(adapter, field)
  if number_utils.is_numeric(adapter[field]) then
    tip_queue.runtime[field] = adapter[field]
  end
end

function tip_queue.configure_runtime(adapter)
  adapter = adapter or {}
  if adapter.clear_presenter == true then
    tip_queue.runtime.presenter = nil
  end
  _try_set_presenter_field(adapter, "presenter")
  _try_set_presenter_field(adapter, "show_tip")
  _try_set_presenter_field(adapter, "tip_presenter")
  if adapter.clear_scheduler == true then
    tip_queue.runtime.scheduler = nil
  end
  _try_set_scheduler_field(adapter, "scheduler")
  _try_set_scheduler_field(adapter, "schedule")
  _apply_test_mode(adapter)
  _apply_numeric_runtime_field(adapter, "event_tip_fast_backlog_threshold")
  _apply_numeric_runtime_field(adapter, "event_tip_fast_seconds")
  _dispatch_next_tip()
end

function tip_queue.enqueue(intent)
  local tip = _normalize_intent(intent)
  if tip == nil then
    return false
  end
  if _has_matching_dedupe_key(tip.dedupe_key) then
    return false
  end
  local pending = tip_queue.pending
  pending[#pending + 1] = tip
  _dispatch_next_tip()
  return true
end

function tip_queue.has_blocking_pending(phase_name)
  if phase_name ~= "inter_turn" then
    return false
  end
  local active_tip = tip_queue.active_tip
  if active_tip ~= nil and active_tip.blocks_inter_turn == true then
    return true
  end
  local pending = tip_queue.pending
  for i = 1, #pending do
    if pending[i].blocks_inter_turn == true then
      return true
    end
  end
  return false
end

function tip_queue.clear()
  tip_queue.pending = {}
  tip_queue.active_tip = nil
  tip_queue.epoch = tip_queue.epoch + 1
end

function tip_queue.snapshot()
  return {
    has_presenter = type(tip_queue.runtime.presenter) == "function",
    has_scheduler = type(tip_queue.runtime.scheduler) == "function",
    pending_count = #tip_queue.pending,
    active_text = tip_queue.active_tip and tip_queue.active_tip.text or nil,
    epoch = tip_queue.epoch,
    test_mode = tip_queue.runtime.test_mode,
  }
end

return tip_queue

--[[ mutate4lua-manifest
version=2
projectHash=5ff16988929956df
scope.0.id=chunk:src/foundation/tips.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=279
scope.0.semanticHash=1e3a3dfcaf31eabf
scope.1.id=function:_warn:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=7cc1be2dd6257ac1
scope.2.id=function:_normalize_duration:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=30
scope.2.semanticHash=fef456e171d841fa
scope.3.id=function:_backlog_threshold:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=34
scope.3.semanticHash=452f535ed965d676
scope.4.id=function:_fast_seconds:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=38
scope.4.semanticHash=fdd722cb6dda27f2
scope.5.id=function:_apply_backlog_acceleration:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=50
scope.5.semanticHash=e2bf986f93b74069
scope.6.id=function:_normalize_text:52
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=61
scope.6.semanticHash=d1b7f970095acb67
scope.7.id=function:_normalize_intent:63
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=81
scope.7.semanticHash=06ba5713853e4367
scope.8.id=function:_present_tip:100
scope.8.kind=function
scope.8.startLine=100
scope.8.endLine=114
scope.8.semanticHash=d3f21af2eb9d1cb5
scope.9.id=function:_wrapped:124
scope.9.kind=function
scope.9.startLine=124
scope.9.endLine=127
scope.9.semanticHash=1951c3be33929a3d
scope.10.id=function:_schedule_release:116
scope.10.kind=function
scope.10.startLine=116
scope.10.endLine=140
scope.10.semanticHash=3cb1ae2eff3c0b85
scope.11.id=function:_effective_duration:142
scope.11.kind=function
scope.11.startLine=142
scope.11.endLine=144
scope.11.semanticHash=406b9a881801ca05
scope.12.id=function:_release_tip:148
scope.12.kind=function
scope.12.startLine=148
scope.12.endLine=157
scope.12.semanticHash=998a699e81fb1e70
scope.13.id=function:anonymous@168:168
scope.13.kind=function
scope.13.startLine=168
scope.13.endLine=170
scope.13.semanticHash=8485b5fe18ea3072
scope.14.id=function:_activate_next_pending:159
scope.14.kind=function
scope.14.startLine=159
scope.14.endLine=171
scope.14.semanticHash=5680174383cf2771
scope.15.id=function:_dispatch_next_tip:173
scope.15.kind=function
scope.15.startLine=173
scope.15.endLine=178
scope.15.semanticHash=e9204fb2197e0dad
scope.16.id=function:_try_set_runtime_field:180
scope.16.kind=function
scope.16.startLine=180
scope.16.endLine=186
scope.16.semanticHash=eb6efada6b55b79a
scope.17.id=function:anonymous@191:191
scope.17.kind=function
scope.17.startLine=191
scope.17.endLine=191
scope.17.semanticHash=8ec3ce0341c7963a
scope.18.id=function:_try_set_presenter_field:188
scope.18.kind=function
scope.18.startLine=188
scope.18.endLine=192
scope.18.semanticHash=a737939eec189efc
scope.19.id=function:_try_set_scheduler_field:194
scope.19.kind=function
scope.19.startLine=194
scope.19.endLine=197
scope.19.semanticHash=016a52cb28dcf12a
scope.20.id=function:_apply_test_mode:199
scope.20.kind=function
scope.20.startLine=199
scope.20.endLine=203
scope.20.semanticHash=27d868ff0e5bc9b3
scope.21.id=function:_apply_numeric_runtime_field:205
scope.21.kind=function
scope.21.startLine=205
scope.21.endLine=209
scope.21.semanticHash=bed47cd09da626ae
scope.22.id=function:tip_queue.configure_runtime:211
scope.22.kind=function
scope.22.startLine=211
scope.22.endLine=228
scope.22.semanticHash=028b550c23c4ee2a
scope.23.id=function:tip_queue.enqueue:230
scope.23.kind=function
scope.23.startLine=230
scope.23.endLine=242
scope.23.semanticHash=c2a4318a79147b53
scope.24.id=function:tip_queue.clear:261
scope.24.kind=function
scope.24.startLine=261
scope.24.endLine=265
scope.24.semanticHash=b70b62b9d7f0f98e
scope.25.id=function:tip_queue.snapshot:267
scope.25.kind=function
scope.25.startLine=267
scope.25.endLine=276
scope.25.semanticHash=d8d9cb6806e75fb8
]]
