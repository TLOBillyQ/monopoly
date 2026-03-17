local startup_policy = {}

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function _resolve_mode(globals)
  local raw_mode = globals and globals.MONO_BUILD_MODE or nil
  if raw_mode == nil or raw_mode == "" then
    return "dev"
  end
  assert(raw_mode == "dev" or raw_mode == "release", "invalid MONO_BUILD_MODE: " .. tostring(raw_mode))
  return raw_mode
end

function startup_policy.resolve(globals)
  local startup_profile = globals and globals.STARTUP_TEST_PROFILE or nil
  local resolved_profile = "default"
  if _is_non_empty_string(startup_profile) then
    resolved_profile = startup_profile
  end

  return {
    mode = _resolve_mode(globals),
    profile_name = resolved_profile,
  }
end

return startup_policy
