local startup_policy = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

function startup_policy.resolve(globals)
  local build_mode = globals and globals.MONOPOLY_BUILD_MODE or nil
  local startup_profile = globals and globals.STARTUP_TEST_PROFILE or nil
  local startup_profile_source = globals and globals.STARTUP_PROFILE_SOURCE or nil
  local startup_profile_module = globals and globals.STARTUP_PROFILE_MODULE or nil
  local resolved_profile = "default"
  if _is_non_empty_string(startup_profile) then
    resolved_profile = tostring(startup_profile)
  end

  return {
    build_mode = _is_non_empty_string(build_mode) and tostring(build_mode) or "debug",
    profile_name = resolved_profile,
    profile_source = _is_non_empty_string(startup_profile_source) and tostring(startup_profile_source) or "testing",
    profile_module = _is_non_empty_string(startup_profile_module) and tostring(startup_profile_module) or nil,
  }
end

return startup_policy
