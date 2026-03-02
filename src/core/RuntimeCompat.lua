local runtime_context = require("src.core.RuntimeContext")

local runtime_compat = {}
local state = {
  strict_context_first = false,
  fallback_hits = {
    roles = 0,
    vehicle_helper = 0,
    camera_helper = 0,
  },
}

local function _current()
  return runtime_context.current()
end

local function _can_fallback(ctx)
  if state.strict_context_first and ctx ~= nil then
    return false
  end
  return true
end

local function _mark_fallback(key)
  state.fallback_hits[key] = (state.fallback_hits[key] or 0) + 1
end

function runtime_compat.get_roles()
  local ctx = _current()
  if ctx and type(ctx.roles) == "table" then
    return ctx.roles
  end
  if not _can_fallback(ctx) then
    return nil
  end
  if type(all_roles) == "table" then
    _mark_fallback("roles")
    return all_roles
  end
  if type(ALLROLES) == "table" then
    _mark_fallback("roles")
    return ALLROLES
  end
  return nil
end

function runtime_compat.get_vehicle_helper()
  local ctx = _current()
  if ctx and type(ctx.vehicle_helper) == "table" then
    return ctx.vehicle_helper
  end
  if not _can_fallback(ctx) then
    return nil
  end
  if vehicle_helper ~= nil then
    _mark_fallback("vehicle_helper")
  end
  return vehicle_helper
end

function runtime_compat.get_camera_helper()
  local ctx = _current()
  if ctx and type(ctx.camera_helper) == "table" then
    return ctx.camera_helper
  end
  if not _can_fallback(ctx) then
    return nil
  end
  if camera_helper ~= nil then
    _mark_fallback("camera_helper")
  end
  return camera_helper
end

function runtime_compat.configure(opts)
  opts = opts or {}
  if opts.strict_context_first ~= nil then
    state.strict_context_first = opts.strict_context_first == true
  end
end

function runtime_compat.reset_for_tests()
  state.strict_context_first = false
  state.fallback_hits.roles = 0
  state.fallback_hits.vehicle_helper = 0
  state.fallback_hits.camera_helper = 0
end

function runtime_compat.get_fallback_hits()
  return {
    roles = state.fallback_hits.roles,
    vehicle_helper = state.fallback_hits.vehicle_helper,
    camera_helper = state.fallback_hits.camera_helper,
  }
end

return runtime_compat
