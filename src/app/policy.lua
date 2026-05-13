local startup_policy = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function _resolve_string_or(value, default)
  if _is_non_empty_string(value) then
    return tostring(value)
  end
  return default
end

function startup_policy.resolve(globals)
  local resolved_profile = _resolve_string_or(
    globals and globals.STARTUP_TEST_PROFILE, "default"
  )
  local resolved_build_mode = _resolve_string_or(
    globals and globals.MONOPOLY_BUILD_MODE, "debug"
  )
  local managed = globals and globals.MONOPOLY_STARTUP_MANAGED == true
  if resolved_build_mode == "release" then
    managed = false
  end

  return {
    build_mode = resolved_build_mode,
    profile_name = resolved_profile,
    managed = managed,
  }
end

function startup_policy.is_release(resolved)
  return resolved ~= nil and resolved.build_mode == "release"
end

return startup_policy
