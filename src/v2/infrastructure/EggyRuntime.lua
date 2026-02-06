local runtime = {}
runtime.__index = runtime

local function _call_role(role, method_name, ...)
  if role == nil then
    return nil
  end
  local fn = role[method_name]
  if type(fn) ~= "function" then
    return nil
  end

  local ok, result = pcall(fn, role, ...)
  if ok then
    return result
  end
  ok, result = pcall(fn, ...)
  if ok then
    return result
  end
  return nil
end

local function _resolve_role_id(role)
  local role_id = _call_role(role, "get_roleid")
  if role_id ~= nil then
    return role_id
  end
  return role.role_id
end

local function _resolve_role_name(role)
  local name = _call_role(role, "get_name")
  if name ~= nil then
    return name
  end
  return role.name
end

function runtime.new()
  local instance = {}
  setmetatable(instance, runtime)
  return instance
end

function runtime:register_game_init(callback)
  assert(callback ~= nil, "missing game init callback")
  RegisterTriggerEvent({ EVENT.GAME_INIT }, function()
    callback()
  end)
end

function runtime:start_tick(frame_interval, callback)
  local interval = frame_interval or 1
  local dt = math.tofixed(interval + 1) / 30.0
  SetFrameOut(interval, function()
    callback(dt)
  end, -1)
end

function runtime:set_timeout(seconds, callback)
  SetTimeOut(seconds, callback)
end

function runtime:get_all_roles()
  if all_roles then
    return all_roles
  end
  if GameAPI and GameAPI.get_all_valid_roles then
    return GameAPI.get_all_valid_roles()
  end
  return {}
end

function runtime:get_online_role_ids()
  if not (GameAPI and GameAPI.get_all_online_roles) then
    return {}
  end
  local roles = GameAPI.get_all_online_roles() or {}
  local ids = {}
  for _, role in ipairs(roles) do
    local role_id = _resolve_role_id(role)
    if role_id ~= nil then
      ids[#ids + 1] = role_id
    end
  end
  return ids
end

function runtime:find_role_by_id(role_id)
  for _, role in ipairs(self:get_all_roles()) do
    local rid = _resolve_role_id(role)
    if rid == role_id then
      return role
    end
  end
  return nil
end

function runtime:get_role_name(role)
  return _resolve_role_name(role)
end

function runtime:get_role_id(role)
  return _resolve_role_id(role)
end

return runtime
