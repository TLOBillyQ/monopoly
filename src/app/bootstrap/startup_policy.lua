local startup_policy = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

function startup_policy.resolve(globals)
  local startup_profile = globals and globals.STARTUP_TEST_PROFILE or nil
  local resolved_profile = "default"
  if _is_non_empty_string(startup_profile) then
    resolved_profile = tostring(startup_profile)
  end

  return {
    profile_name = resolved_profile,
  }
end

return startup_policy
