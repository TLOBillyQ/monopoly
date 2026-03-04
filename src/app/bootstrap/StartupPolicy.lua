local startup_policy = {}
local release_profile_whitelist = require("src.app.testing.config.ReleaseProfileWhitelist")

local function _is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function _read_truthy_flag(raw)
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

local function _read_release_flag(globals)
  local raw = globals and globals.RELEASE_BUILD or nil
  return _read_truthy_flag(raw)
end

local function _read_release_allow_test_profile(globals)
  local raw = globals and globals.RELEASE_ALLOW_TEST_PROFILE or nil
  return _read_truthy_flag(raw)
end

function startup_policy.resolve(globals)
  local release_mode = _read_release_flag(globals)
  local release_allow_test_profile = _read_release_allow_test_profile(globals)
  local startup_profile = globals and globals.STARTUP_TEST_PROFILE or nil
  local resolved_profile = "default"
  if release_mode and release_allow_test_profile and _is_non_empty_string(startup_profile) then
    assert(
      release_profile_whitelist.contains(startup_profile),
      "[Eggy] release startup profile not allowed: " .. tostring(startup_profile)
    )
    resolved_profile = startup_profile
  elseif not release_mode and _is_non_empty_string(startup_profile) then
    resolved_profile = startup_profile
  end
  return {
    release_mode = release_mode,
    release_allow_test_profile = release_allow_test_profile,
    profile_name = resolved_profile,
    force_non_p1_ai = not release_mode,
    fail_fast_when_roles_empty = release_mode,
  }
end

return startup_policy
