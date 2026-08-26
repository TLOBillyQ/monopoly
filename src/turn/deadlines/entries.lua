local number_utils = require("src.foundation.number")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log")

local entries = {}

local _default_thresholds = { 5, 3 }
local _peek_result = {}

local function _resolve_thresholds()
  local cfg = timing.deadline_warning_thresholds
  if type(cfg) ~= "table" then
    return _default_thresholds
  end
  return cfg
end

function entries.resolve_timeout(opts)
  if not opts then
    return 0
  end
  if number_utils.is_numeric(opts.timeout_seconds) and opts.timeout_seconds > 0 then
    return opts.timeout_seconds
  end
  return 0
end

function entries.new_entry(scope, opts, timeout)
  return {
    scope = scope,
    elapsed = 0,
    timeout = timeout,
    on_timeout = opts.on_timeout,
    on_warn = opts.on_warn,
    priority = number_utils.is_numeric(opts.priority) and opts.priority or 0,
    fired_warn_5s = false,
    fired_warn_3s = false,
    fired_timeout = false,
    started_at = nil,
  }
end

local function _call_deadline_callback(callback, label, warn_args, ...)
  if type(callback) ~= "function" then
    return
  end
  local ok, err = pcall(callback, ...)
  if not ok then
    logger.warn("[Eggy]", label, table.unpack(warn_args), tostring(err))
  end
end

local function _fire_warn(entry, level)
  _call_deadline_callback(entry.on_warn, "DeadlineService.on_warn error", { entry.scope, level }, level)
end

local function _warn_thresholds(thresholds)
  return thresholds[1] or 5, thresholds[2] or 3
end

local function _should_fire_warn_5s(entry, remaining, warn_5s, warn_3s)
  return not entry.fired_warn_5s and remaining <= warn_5s and remaining > warn_3s
end

local function _should_fire_warn_3s(entry, remaining, warn_3s)
  return not entry.fired_warn_3s and remaining <= warn_3s and remaining > 0
end

local function _maybe_fire_warns(entry, remaining, thresholds)
  local warn_5s, warn_3s = _warn_thresholds(thresholds)
  if _should_fire_warn_5s(entry, remaining, warn_5s, warn_3s) then
    entry.fired_warn_5s = true
    _fire_warn(entry, "warn_5s")
  end
  if _should_fire_warn_3s(entry, remaining, warn_3s) then
    entry.fired_warn_3s = true
    _fire_warn(entry, "warn_3s")
  end
end

local function _active_level_from_remaining(remaining, thresholds)
  local warn_3s = thresholds[2] or 3
  local warn_5s = thresholds[1] or 5
  if remaining <= warn_3s then
    return "warn_3s"
  end
  if remaining <= warn_5s then
    return "warn_5s"
  end
  return "normal"
end

local function _level_from_remaining(remaining, thresholds)
  if remaining <= 0 then
    return "expired"
  end
  return _active_level_from_remaining(remaining, thresholds)
end

function entries.build_peek_result(entry)
  local remaining = entry.timeout - entry.elapsed
  if remaining < 0 then remaining = 0 end
  _peek_result.scope = entry.scope
  _peek_result.remaining_seconds = remaining
  _peek_result.elapsed_seconds = entry.elapsed
  _peek_result.timeout_seconds = entry.timeout
  _peek_result.level = _level_from_remaining(remaining, _resolve_thresholds())
  return _peek_result
end

function entries.collect_expired_entry(scope, entry, dt, expired_n, expired_scopes, expired_entries)
  if entry.fired_timeout then
    return expired_n
  end
  entry.elapsed = (entry.elapsed or 0) + dt
  local remaining = entry.timeout - entry.elapsed
  _maybe_fire_warns(entry, remaining, _resolve_thresholds())
  if entry.elapsed < entry.timeout then
    return expired_n
  end
  entry.fired_timeout = true
  expired_n = expired_n + 1
  expired_scopes[expired_n] = scope
  expired_entries[expired_n] = entry
  return expired_n
end

local function _fire_timeout(entry, scope)
  _call_deadline_callback(entry.on_timeout, "DeadlineService.on_timeout error", { scope }, scope)
end

function entries.expire_collected_entries(active, expired_n, expired_scopes, expired_entries)
  for i = 1, expired_n do
    local scope = expired_scopes[i]
    local entry = expired_entries[i]
    expired_scopes[i] = nil
    expired_entries[i] = nil
    active[scope] = nil
    _fire_timeout(entry, scope)
  end
end

return entries

--[[ mutate4lua-manifest
version=4
projectHash=6c96367ca478666e
scope.0.id=chunk:src/turn/deadlines/entries.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=133
scope.0.semanticHash=0245bc5f8a49ce4f
scope.1.id=function:_resolve_thresholds
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=16
scope.1.semanticHash=2efacd5484c0afd5
scope.2.id=function:entries.resolve_timeout
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=499030bc9e4ae751
scope.3.id=function:entries.new_entry
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=41
scope.3.semanticHash=98fb62eb6ca6a348
scope.4.id=function:_call_deadline_callback
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=51
scope.4.semanticHash=e87738e2f899d8c2
scope.5.id=function:_fire_warn
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=55
scope.5.semanticHash=02763cbd96913f0b
scope.6.id=function:_maybe_fire_warns
scope.6.kind=function
scope.6.startLine=57
scope.6.endLine=68
scope.6.semanticHash=293113aa952e3eae
scope.7.id=function:_active_level_from_remaining
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=80
scope.7.semanticHash=a03f5fcc7666d5eb
scope.8.id=function:_level_from_remaining
scope.8.kind=function
scope.8.startLine=82
scope.8.endLine=87
scope.8.semanticHash=f9ed99a667db8d66
scope.9.id=function:entries.build_peek_result
scope.9.kind=function
scope.9.startLine=89
scope.9.endLine=98
scope.9.semanticHash=2e17bd7109c41f43
scope.10.id=function:entries.collect_expired_entry
scope.10.kind=function
scope.10.startLine=100
scope.10.endLine=115
scope.10.semanticHash=4fff5c556af4a805
scope.11.id=function:_fire_timeout
scope.11.kind=function
scope.11.startLine=117
scope.11.endLine=119
scope.11.semanticHash=7481ad7beb2ce597
scope.12.id=function:entries.expire_collected_entries
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=130
scope.12.semanticHash=e2e3831dab09dd09
]]
