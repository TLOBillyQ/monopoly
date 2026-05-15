local test_profiles = require("src.app.testing.test_profiles")

local resolver = {}
local default_map_module = "src.config.content.default_map"

local function _join_profile_names(profile_names)
  if type(profile_names) ~= "table" or #profile_names == 0 then
    return "default"
  end
  return table.concat(profile_names, ", ")
end

local function _resolve_name(profile_name)
  if profile_name == nil or profile_name == "" then
    return "default"
  end
  assert(type(profile_name) == "string", "invalid profile_name type")
  assert(
    test_profiles.has(profile_name),
    "unknown test profile: " .. tostring(profile_name)
      .. "; available profiles: " .. _join_profile_names(test_profiles.names())
  )
  return profile_name
end

function resolver.resolve_profile(profile_name)
  local name = _resolve_name(profile_name)
  local profile = test_profiles.get(name)
  assert(profile ~= nil, "missing test profile: " .. tostring(name))
  return profile
end

function resolver.resolve_map(profile_name)
  resolver.resolve_profile(profile_name)
  local ok, map_or_err = pcall(require, default_map_module)
  assert(ok, "failed to require default map module for profile " .. tostring(profile_name) .. ": " .. tostring(map_or_err))
  return map_or_err
end

function resolver.resolve_bootstrap(profile_name)
  local profile = resolver.resolve_profile(profile_name)
  return profile.bootstrap
end

resolver.available_profiles = test_profiles.names
resolver.available_groups = test_profiles.groups
resolver.profiles_in_group = test_profiles.profiles_in_group

return resolver
