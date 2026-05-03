local role_id_utils = require("src.foundation.identity.role_id")
local runtime_state = require("src.state.runtime_state")

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

  local seen_roles = {}
  runtime.for_each_role_or_global(function(role)
    if not role then
      runtime_state.log_once(state, "warn", "role_control_lock:missing_roles", "role_control_lock missing role list")
      return
    end
    local role_id = role_id_utils.normalize(runtime.resolve_role_id(role) or tostring(role))
    if role_id == nil then
      return
    end
    seen_roles[role_id] = true

    local unit = role.get_ctrl_unit and role.get_ctrl_unit() or nil
    if role_id_utils.read(exempt_by_role, role_id) == true then
      _sync_role_lock(lock_state, role_id, nil, buff_id)
      return
    end
    if not unit then
      _sync_role_lock(lock_state, role_id, nil, buff_id)
      return
    end
    if not _can_apply(unit) then
      runtime_state.log_once(state, "warn", "role_control_lock:missing_buff_api_" .. tostring(role_id), "ctrl_unit missing BuffStateComp:", tostring(role_id))
      return
    end
    _sync_role_lock(lock_state, role_id, unit, buff_id)
  end)

  for role_id, entry in pairs(lock_state.by_role) do
    if not seen_roles[role_id] then
      if entry and entry.owned and entry.unit then
        _remove_lock(entry.unit, buff_id)
      end
      lock_state.by_role[role_id] = nil
    end
  end
end

return lock_policy
