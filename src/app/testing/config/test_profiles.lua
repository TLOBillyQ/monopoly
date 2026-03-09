local raw_profiles = require("Config.testing.test_profiles")

local M = {}
local default_profile = {
  bootstrap = {},
}

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
  if type(profile_name) ~= "string" or profile_name == "" or profile_name == "default" then
    return _deep_copy(default_profile)
  end
  return _deep_copy(profiles[profile_name] or default_profile)
end

function M.has(profile_name)
  return profile_name == "default" or (type(profile_name) == "string" and profiles[profile_name] ~= nil)
end

function M.get(profile_name)
  if profile_name == "default" then
    return _deep_copy(default_profile)
  end
  if not M.has(profile_name) then
    return nil
  end
  return _deep_copy(profiles[profile_name])
end

function M.names()
  local out = { "default" }
  for name in pairs(profiles) do
    out[#out + 1] = name
  end
  table.sort(out, function(left, right)
    if left == "default" then
      return true
    end
    if right == "default" then
      return false
    end
    return left < right
  end)
  return out
end

return M
