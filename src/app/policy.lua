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

  return {
    build_mode = _resolve_string_or(
      globals and globals.MONOPOLY_BUILD_MODE, "debug"
    ),
    profile_name = resolved_profile,
    profile_source = _resolve_string_or(
      globals and globals.STARTUP_PROFILE_SOURCE, "testing"
    ),
    profile_module = _resolve_string_or(
      globals and globals.STARTUP_PROFILE_MODULE, nil
    ),
  }
end

return startup_policy
