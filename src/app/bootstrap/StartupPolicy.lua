local startup_policy = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function _read_release_flag(globals)
  local raw = globals and globals.RELEASE_BUILD or nil
  if raw == true then
    return true
  end
  if raw == 1 then
    return true
  end
  if raw == "1" then
    return true
  end
  if raw == "true" then
    return true
  end
  if raw == "TRUE" then
    return true
  end
  return false
end

function startup_policy.resolve(globals)
  local release_mode = _read_release_flag(globals)
  local startup_profile = globals and globals.STARTUP_TEST_PROFILE or nil
  local resolved_profile = "default"
  if not release_mode and _is_non_empty_string(startup_profile) then
    resolved_profile = startup_profile
  end
  return {
    release_mode = release_mode,
    profile_name = resolved_profile,
    force_non_p1_ai = not release_mode,
    fail_fast_when_roles_empty = release_mode,
  }
end

return startup_policy
