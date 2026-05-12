local number_utils = require("src.foundation.lang.number")
local timing = require("src.config.gameplay.timing")
local logger = require("src.foundation.log.logger")
local runtime_state = require("src.state.runtime")

local M = {}

local function _resolve_thresholds()
  local cfg = timing.deadline_warning_thresholds
  if type(cfg) ~= "table" then
    return { 5, 3 }
  end
  return cfg
end

local function _ensure_active(state)
  local deadlines = runtime_state.ensure_deadlines(state)
  return deadlines.active
end

local function _resolve_timeout(opts)
  if not opts then
    return 0
  end
  if number_utils.is_numeric(opts.timeout_seconds) and opts.timeout_seconds > 0 then
    return opts.timeout_seconds
  end
  return 0
end

local function _new_entry(scope, opts, timeout)
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

local function _fire_warn(entry, level)
  if type(entry.on_warn) ~= "function" then
    return
  end
  local ok, err = pcall(entry.on_warn, level)
  if not ok then
    logger.warn("[Eggy]", "DeadlineService.on_warn error", entry.scope, level, tostring(err))
  end
end

local function _maybe_fire_warns(entry, remaining, thresholds)
  local warn_5s = thresholds[1] or 5
  local warn_3s = thresholds[2] or 3
  if not entry.fired_warn_5s and remaining <= warn_5s and remaining > warn_3s then
    entry.fired_warn_5s = true
    _fire_warn(entry, "warn_5s")
  end
  if not entry.fired_warn_3s and remaining <= warn_3s and remaining > 0 then
    entry.fired_warn_3s = true
    _fire_warn(entry, "warn_3s")
  end
end

local function _level_from_remaining(remaining, thresholds)
  if remaining <= 0 then
    return "expired"
  end
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

function M.start(state, scope, opts)
  assert(type(state) == "table", "missing state")
  assert(type(scope) == "string" and scope ~= "", "invalid scope")
  opts = opts or {}
  local timeout = _resolve_timeout(opts)
  if timeout <= 0 then
    return nil
  end
  local active = _ensure_active(state)
  active[scope] = _new_entry(scope, opts, timeout)
  return active[scope]
end

function M.cancel(state, scope)
  if type(state) ~= "table" or type(scope) ~= "string" then
    return false
  end
  local active = _ensure_active(state)
  if active[scope] == nil then
    return false
  end
  active[scope] = nil
  return true
end

local function _build_peek_result(entry)
  local remaining = entry.timeout - entry.elapsed
  if remaining < 0 then remaining = 0 end
  return {
    scope = entry.scope,
    remaining_seconds = remaining,
    elapsed_seconds = entry.elapsed,
    timeout_seconds = entry.timeout,
    level = _level_from_remaining(remaining, _resolve_thresholds()),
  }
end

function M.peek(state, scope)
  if type(state) ~= "table" then
    return nil
  end
  local active = _ensure_active(state)
  if scope == "primary" then
    local primary = nil
    for _, entry in pairs(active) do
      if primary == nil or (entry.priority or 0) > (primary.priority or 0) then
        primary = entry
      end
    end
    return primary and _build_peek_result(primary) or nil
  end
  local entry = active[scope]
  return entry and _build_peek_result(entry) or nil
end

function M.tick(state, dt)
  if type(state) ~= "table" then
    return
  end
  if not number_utils.is_numeric(dt) or dt <= 0 then
    return
  end
  local active = _ensure_active(state)
  local thresholds = _resolve_thresholds()
  local expired_scopes = {}
  for scope, entry in pairs(active) do
    if not entry.fired_timeout then
      entry.elapsed = (entry.elapsed or 0) + dt
      local remaining = entry.timeout - entry.elapsed
      _maybe_fire_warns(entry, remaining, thresholds)
      if entry.elapsed >= entry.timeout then
        entry.fired_timeout = true
        expired_scopes[#expired_scopes + 1] = { scope = scope, entry = entry }
      end
    end
  end
  for _, item in ipairs(expired_scopes) do
    active[item.scope] = nil
    if type(item.entry.on_timeout) == "function" then
      local ok, err = pcall(item.entry.on_timeout, item.scope)
      if not ok then
        logger.warn("[Eggy]", "DeadlineService.on_timeout error", item.scope, tostring(err))
      end
    end
  end
end

function M.is_active(state, scope)
  if type(state) ~= "table" or type(scope) ~= "string" then
    return false
  end
  local active = _ensure_active(state)
  return active[scope] ~= nil
end

return M
