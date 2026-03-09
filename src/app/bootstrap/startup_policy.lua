local number_utils = require("src.core.utils.number_utils")

local startup_policy = {}
local valid_ai_modes = {
  default = true,
  all_except_local_human = true,
}

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

local function _read_ai_mode(globals)
  local raw = globals and globals.STARTUP_AI_MODE or nil
  if raw == nil or raw == "" then
    return "default"
  end
  assert(type(raw) == "string", "invalid STARTUP_AI_MODE type")
  assert(valid_ai_modes[raw] == true, "invalid STARTUP_AI_MODE: " .. tostring(raw))
  return raw
end

local function _read_local_human_role_id(globals)
  local raw = globals and globals.STARTUP_LOCAL_HUMAN_ROLE_ID or nil
  if raw == nil or raw == "" then
    return nil
  end
  return number_utils.to_integer(raw)
end

function startup_policy.resolve(globals)
  local release_mode = _read_release_flag(globals)
  local release_allow_test_profile = _read_release_allow_test_profile(globals)
  local startup_profile = globals and globals.STARTUP_TEST_PROFILE or nil
  local ai_mode = _read_ai_mode(globals)
  local local_human_role_id = _read_local_human_role_id(globals)
  local resolved_profile = "default"
  if release_mode and release_allow_test_profile and _is_non_empty_string(startup_profile) then
    resolved_profile = startup_profile
  elseif not release_mode and _is_non_empty_string(startup_profile) then
    resolved_profile = startup_profile
  end
  return {
    release_mode = release_mode,
    release_allow_test_profile = release_allow_test_profile,
    profile_name = resolved_profile,
    ai_mode = ai_mode,
    local_human_role_id = local_human_role_id,
    force_non_p1_ai = not release_mode,
    fail_fast_when_roles_empty = release_mode,
  }
end

return startup_policy
