local role_id_utils = require("src.foundation.identity")
local runtime_state = require("src.ui.state.runtime")

local lock_policy = {}

local function _resolve_lock_state(state)
  local lock_state = state.role_control_lock
  if lock_state then
    return lock_state
  end
  lock_state = {
    by_role = {},
  }
  state.role_control_lock = lock_state
  return lock_state
end

local function _can_apply(unit)
  return unit
    and unit.get_state_count
    and unit.add_state
    and unit.remove_state
end

local function _remove_lock(unit, buff_id)
  if not unit then
    return
  end
  local count = unit.get_state_count(buff_id)
  if count and count > 0 then
    unit.remove_state(buff_id)
  end
end

local function _sync_role_lock(lock_state, role_id, unit, buff_id)
  local normalized_role_id = role_id_utils.normalize(role_id)
  if normalized_role_id == nil then
    return
  end
  local entry = role_id_utils.read(lock_state.by_role, normalized_role_id) or {}
  if entry.unit and entry.unit ~= unit and entry.owned then
    _remove_lock(entry.unit, buff_id)
  end

  if not unit then
    role_id_utils.write(lock_state.by_role, normalized_role_id, nil)
    return
  end

  local count = unit.get_state_count(buff_id)
  if count == 0 then
    unit.add_state(buff_id)
    entry.owned = true
  else
    entry.owned = entry.owned == true
  end
  entry.unit = unit
  role_id_utils.write(lock_state.by_role, normalized_role_id, entry)
end

local function _release_all(lock_state, buff_id)
  for role_id, entry in pairs(lock_state.by_role) do
    if entry and entry.owned and entry.unit then
      _remove_lock(entry.unit, buff_id)
    end
    lock_state.by_role[role_id] = nil
  end
end

local _sync_state, _sync_lock_state, _sync_exempt_by_role, _sync_buff_id, _sync_runtime, _sync_seen_roles
local _seen_roles = {}

local function _clear_seen_roles()
  for k in pairs(_seen_roles) do
    _seen_roles[k] = nil
  end
end

local function _begin_sync_context(state, lock_state, exempt_by_role, buff_id, runtime)
  _sync_state = state
  _sync_lock_state = lock_state
  _sync_exempt_by_role = exempt_by_role
  _sync_buff_id = buff_id
  _sync_runtime = runtime
  _sync_seen_roles = _seen_roles
end

local function _end_sync_context()
  _sync_state = nil
  _sync_lock_state = nil
  _sync_exempt_by_role = nil
  _sync_buff_id = nil
  _sync_runtime = nil
end

local function _prune_unseen_roles(lock_state, buff_id)
  for role_id, entry in pairs(lock_state.by_role) do
    if not _seen_roles[role_id] then
      if entry and entry.owned and entry.unit then
        _remove_lock(entry.unit, buff_id)
      end
      lock_state.by_role[role_id] = nil
    end
  end
end

local function _resolve_ctrl_unit(role)
  return role.get_ctrl_unit and role.get_ctrl_unit() or nil
end

local function _apply_seen_role_lock(role, role_id)
  local unit = _resolve_ctrl_unit(role)
  local exempt = role_id_utils.read(_sync_exempt_by_role, role_id) == true
  if exempt or not unit then
    _sync_role_lock(_sync_lock_state, role_id, nil, _sync_buff_id)
    return
  end
  if not _can_apply(unit) then
    runtime_state.log_once(_sync_state, "warn", "role_control_lock:missing_buff_api_" .. tostring(role_id), "ctrl_unit missing BuffStateComp:", tostring(role_id))
    return
  end
  _sync_role_lock(_sync_lock_state, role_id, unit, _sync_buff_id)
end

local function _sync_role_callback(role)
  if not role then
    runtime_state.log_once(_sync_state, "warn", "role_control_lock:missing_roles", "role_control_lock missing role list")
    return
  end
  local role_id = role_id_utils.normalize(_sync_runtime.resolve_role_id(role) or tostring(role))
  if role_id == nil then
    return
  end
  _sync_seen_roles[role_id] = true
  _apply_seen_role_lock(role, role_id)
end

function lock_policy.sync(state, enabled, deps)
  assert(state ~= nil, "missing state")
  assert(deps ~= nil and deps.runtime ~= nil, "missing deps.runtime")
  local runtime = deps.runtime
  local lock_state = _resolve_lock_state(state)
  local exempt_by_role = state.role_control_lock_exempt_by_role or {}
  local buff_id = Enums and Enums.BuffState and Enums.BuffState.BUFF_FORBID_CONTROL or nil
  if not buff_id then
    runtime_state.log_once(state, "warn", "role_control_lock:missing_buff_enum", "missing Enums.BuffState.BUFF_FORBID_CONTROL")
    return
  end

  if enabled ~= true then
    _release_all(lock_state, buff_id)
    return
  end

  _clear_seen_roles()
  _begin_sync_context(state, lock_state, exempt_by_role, buff_id, runtime)

  runtime.for_each_role_or_global(_sync_role_callback)

  _end_sync_context()
  _prune_unseen_roles(lock_state, buff_id)
end

return lock_policy

--[[ mutate4lua-manifest
version=2
projectHash=a8ca9f6221c2d64a
scope.0.id=chunk:src/ui/input/role_control_lock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=165
scope.0.semanticHash=e5a5d0435b12a1fe
scope.1.id=function:_resolve_lock_state:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=16
scope.1.semanticHash=fd63d251b4ba4afd
scope.2.id=function:_can_apply:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=2b138eacbb868b59
scope.3.id=function:_remove_lock:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=33
scope.3.semanticHash=9a9a0e313c1497f8
scope.4.id=function:_sync_role_lock:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=59
scope.4.semanticHash=6d127dfd134120b3
scope.5.id=function:_begin_sync_context:79
scope.5.kind=function
scope.5.startLine=79
scope.5.endLine=86
scope.5.semanticHash=075d18c713a30f7b
scope.6.id=function:_end_sync_context:88
scope.6.kind=function
scope.6.startLine=88
scope.6.endLine=94
scope.6.semanticHash=58f602ceff76dc53
scope.7.id=function:_resolve_ctrl_unit:107
scope.7.kind=function
scope.7.startLine=107
scope.7.endLine=109
scope.7.semanticHash=cb2feb0939292b35
scope.8.id=function:_apply_seen_role_lock:111
scope.8.kind=function
scope.8.startLine=111
scope.8.endLine=123
scope.8.semanticHash=204d7643ce945ebd
scope.9.id=function:_sync_role_callback:125
scope.9.kind=function
scope.9.startLine=125
scope.9.endLine=136
scope.9.semanticHash=d99398edf6f66d3a
scope.10.id=function:lock_policy.sync:138
scope.10.kind=function
scope.10.startLine=138
scope.10.endLine=162
scope.10.semanticHash=a091311e0001aa69
]]
