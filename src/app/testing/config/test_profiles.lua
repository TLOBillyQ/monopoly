local raw_profiles = require("Config.testing.test_profiles")

local M = {}

local function _deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, child in pairs(value) do
    out[key] = _deep_copy(child)
  end
  return out
end

local function _validate_profiles(profiles)
  assert(type(profiles) == "table", "invalid test profiles root")
  assert(type(profiles.default) == "table", "missing default test profile")
  for profile_name, profile in pairs(profiles) do
    assert(type(profile_name) == "string", "invalid test profile name")
    assert(type(profile) == "table", "invalid test profile payload: " .. tostring(profile_name))
    if profile.bootstrap ~= nil then
      assert(type(profile.bootstrap) == "table", "invalid bootstrap payload: " .. tostring(profile_name))
    end
  end
  return profiles
end

local profiles = _validate_profiles(raw_profiles)

function M.resolve(profile_name)
  if type(profile_name) ~= "string" or profile_name == "" then
    return _deep_copy(profiles.default)
  end
  return _deep_copy(profiles[profile_name] or profiles.default)
end

function M.has(profile_name)
  return type(profile_name) == "string" and profiles[profile_name] ~= nil
end

function M.get(profile_name)
  if not M.has(profile_name) then
    return nil
  end
  return _deep_copy(profiles[profile_name])
end

function M.names()
  local out = {}
  for name in pairs(profiles) do
    out[#out + 1] = name
  end
  table.sort(out)
  return out
end

return M
