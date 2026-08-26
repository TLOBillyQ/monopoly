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

-- unit 上还没有 buff 时才由我们加，并记 owned；已经有 buff 说明是别处加的，
-- 沿用原 owned 判定（归一成布尔）。
local function _acquire_lock(entry, unit, buff_id)
  local count = unit.get_state_count(buff_id)
  if count == 0 then
    unit.add_state(buff_id)
    entry.owned = true
  else
    entry.owned = entry.owned == true
  end
  entry.unit = unit
end

-- 已拥有旧单位锁时:新单位不同则先移除旧锁,同单位保持。
local function _should_remove_lock(entry, unit)
  return entry.unit and entry.unit ~= unit and entry.owned
end

local function _lock_entry(lock_state, normalized_role_id)
  return role_id_utils.read(lock_state.by_role, normalized_role_id) or {}
end

local function _sync_role_lock(lock_state, role_id, unit, buff_id)
  local normalized_role_id = role_id_utils.normalize(role_id)
  if normalized_role_id == nil then
    return
  end
  local entry = _lock_entry(lock_state, normalized_role_id)
  if _should_remove_lock(entry, unit) then
    _remove_lock(entry.unit, buff_id)
  end

  if not unit then
    role_id_utils.write(lock_state.by_role, normalized_role_id, nil)
    return
  end

  _acquire_lock(entry, unit, buff_id)
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

local function _remove_owned_lock(entry, buff_id)
  if entry and entry.owned and entry.unit then
    _remove_lock(entry.unit, buff_id)
  end
end

local function _prune_unseen_roles(lock_state, buff_id)
  for role_id, entry in pairs(lock_state.by_role) do
    if not _seen_roles[role_id] then
      _remove_owned_lock(entry, buff_id)
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

local function _assert_sync_args(state, deps)
  assert(state ~= nil, "missing state")
  assert(deps ~= nil and deps.runtime ~= nil, "missing deps.runtime")
end

local function _resolve_buff_id()
  return Enums and Enums.BuffState and Enums.BuffState.BUFF_FORBID_CONTROL or nil
end

-- 遍历当前所有角色重建锁，然后回收这一轮没见到的角色。
local function _sync_locked_roles(state, lock_state, exempt_by_role, buff_id, runtime)
  _clear_seen_roles()
  _begin_sync_context(state, lock_state, exempt_by_role, buff_id, runtime)

  runtime.for_each_role_or_global(_sync_role_callback)

  _end_sync_context()
  _prune_unseen_roles(lock_state, buff_id)
end

function lock_policy.sync(state, enabled, deps)
  _assert_sync_args(state, deps)
  local runtime = deps.runtime
  local lock_state = _resolve_lock_state(state)
  local exempt_by_role = state.role_control_lock_exempt_by_role or {}
  local buff_id = _resolve_buff_id()
  if not buff_id then
    runtime_state.log_once(state, "warn", "role_control_lock:missing_buff_enum", "missing Enums.BuffState.BUFF_FORBID_CONTROL")
    return
  end

  if enabled ~= true then
    _release_all(lock_state, buff_id)
    return
  end

  _sync_locked_roles(state, lock_state, exempt_by_role, buff_id, runtime)
end

return lock_policy

--[[ mutate4lua-manifest
version=4
projectHash=bcbcdec26bf4e4de
scope.0.id=chunk:src/ui/input/role_control_lock.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=188
scope.0.semanticHash=2d4c79321a04aa7f
scope.1.id=function:_resolve_lock_state
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=16
scope.1.semanticHash=c82d1cc02efb25b9
scope.2.id=function:_can_apply
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=764da791c1b39ac7
scope.3.id=function:_remove_lock
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=33
scope.3.semanticHash=ebc11f0f33e572c9
scope.4.id=function:_acquire_lock
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=46
scope.4.semanticHash=e48f29e20adfc413
scope.5.id=function:_sync_role_lock
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=65
scope.5.semanticHash=6f52c5680b806be9
scope.6.id=function:_release_all
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=74
scope.6.semanticHash=66bae6aeb405851c
scope.7.id=function:_clear_seen_roles
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=83
scope.7.semanticHash=c52367dcd62d5b7e
scope.8.id=function:_begin_sync_context
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=92
scope.8.semanticHash=af85a9d1e9b9e8af
scope.9.id=function:_end_sync_context
scope.9.kind=function
scope.9.startLine=94
scope.9.endLine=100
scope.9.semanticHash=0a031a8527c8aab8
scope.10.id=function:_remove_owned_lock
scope.10.kind=function
scope.10.startLine=102
scope.10.endLine=106
scope.10.semanticHash=0a8521825d8c1049
scope.11.id=function:_prune_unseen_roles
scope.11.kind=function
scope.11.startLine=108
scope.11.endLine=115
scope.11.semanticHash=6e0e6117ef273ca3
scope.12.id=function:_resolve_ctrl_unit
scope.12.kind=function
scope.12.startLine=117
scope.12.endLine=119
scope.12.semanticHash=bb50598365b9161a
scope.13.id=function:_apply_seen_role_lock
scope.13.kind=function
scope.13.startLine=121
scope.13.endLine=133
scope.13.semanticHash=0f3d6c8eb1a3289f
scope.14.id=function:_sync_role_callback
scope.14.kind=function
scope.14.startLine=135
scope.14.endLine=146
scope.14.semanticHash=fce2b9314f941663
scope.15.id=function:_assert_sync_args
scope.15.kind=function
scope.15.startLine=148
scope.15.endLine=151
scope.15.semanticHash=6c72349b6a4c0350
scope.16.id=function:_resolve_buff_id
scope.16.kind=function
scope.16.startLine=153
scope.16.endLine=155
scope.16.semanticHash=b509dfe52ef2592d
scope.17.id=function:_sync_locked_roles
scope.17.kind=function
scope.17.startLine=158
scope.17.endLine=166
scope.17.semanticHash=ac4afc900f186fa3
scope.18.id=function:lock_policy.sync
scope.18.kind=function
scope.18.startLine=168
scope.18.endLine=185
scope.18.semanticHash=f3787cef8fed8198
]]
