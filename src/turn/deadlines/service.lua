local number_utils = require("src.foundation.number")
local runtime_state = require("src.state.runtime")
local entries = require("src.turn.deadlines.entries")

local service = {}

local function _ensure_active(state)
  local deadlines = runtime_state.ensure_deadlines(state)
  return deadlines.active
end

function service.start(state, scope, opts)
  assert(type(state) == "table", "missing state")
  assert(type(scope) == "string" and scope ~= "", "invalid scope")
  opts = opts or {}
  local timeout = entries.resolve_timeout(opts)
  if timeout <= 0 then
    return nil
  end
  local active = _ensure_active(state)
  active[scope] = entries.new_entry(scope, opts, timeout)
  return active[scope]
end

function service.cancel(state, scope)
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

local function _primary_entry(active)
  local primary = nil
  for _, entry in pairs(active) do
    if primary == nil or (entry.priority or 0) > (primary.priority or 0) then
      primary = entry
    end
  end
  return primary
end

local function _peek_entry(entry)
  return entry and entries.build_peek_result(entry) or nil
end

function service.peek(state, scope)
  if type(state) ~= "table" then
    return nil
  end
  local active = _ensure_active(state)
  if scope == "primary" then
    return _peek_entry(_primary_entry(active))
  end
  return _peek_entry(active[scope])
end

local _expired_scopes = {}
local _expired_entries = {}

function service.tick(state, dt)
  if type(state) ~= "table" then
    return
  end
  if not number_utils.is_numeric(dt) or dt <= 0 then
    return
  end
  local active = _ensure_active(state)
  local expired_n = 0
  for scope, entry in pairs(active) do
    expired_n = entries.collect_expired_entry(scope, entry, dt, expired_n, _expired_scopes, _expired_entries)
  end
  entries.expire_collected_entries(active, expired_n, _expired_scopes, _expired_entries)
end

function service.is_active(state, scope)
  if type(state) ~= "table" or type(scope) ~= "string" then
    return false
  end
  local active = _ensure_active(state)
  return active[scope] ~= nil
end

return service

--[[ mutate4lua-manifest
version=2
projectHash=0fe89fe339f2e50f
scope.0.id=chunk:src/turn/deadlines/service.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=89
scope.0.semanticHash=8ad2cfd9035e8026
scope.1.id=function:_ensure_active:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=10
scope.1.semanticHash=218d50b8035c4f78
scope.2.id=function:service.start:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=23
scope.2.semanticHash=79f98180db3194f1
scope.3.id=function:service.cancel:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=35
scope.3.semanticHash=f7168aae9c48f143
scope.4.id=function:_peek_entry:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=49
scope.4.semanticHash=81bdfc34cf32a4a8
scope.5.id=function:service.peek:51
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=60
scope.5.semanticHash=f96a207e9ef9a6f3
scope.6.id=function:service.is_active:80
scope.6.kind=function
scope.6.startLine=80
scope.6.endLine=86
scope.6.semanticHash=17e700c3fa0b507f
]]
