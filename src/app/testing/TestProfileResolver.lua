local test_profiles = require("src.app.testing.config.TestProfiles")

local resolver = {}

local function _resolve_name(profile_name)
  if profile_name == nil or profile_name == "" then
    return "default"
  end
  assert(type(profile_name) == "string", "invalid profile_name type")
  assert(test_profiles.has(profile_name), "unknown test profile: " .. tostring(profile_name))
  return profile_name
end

function resolver.resolve_profile(profile_name)
  local name = _resolve_name(profile_name)
  local profile = test_profiles.get(name)
  assert(profile ~= nil, "missing test profile: " .. tostring(name))
  return profile
end

function resolver.resolve_map(profile_name)
  local profile = resolver.resolve_profile(profile_name)
  local module_name = profile.map_module or "Config.Maps.DefaultMap"
  local ok, map_or_err = pcall(require, module_name)
  assert(ok, "failed to require map module for profile " .. tostring(profile_name) .. ": " .. tostring(map_or_err))
  return map_or_err
end

function resolver.resolve_bootstrap(profile_name)
  local profile = resolver.resolve_profile(profile_name)
  return profile.bootstrap
end

function resolver.available_profiles()
  return test_profiles.names()
end

return resolver
