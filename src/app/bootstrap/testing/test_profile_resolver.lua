local test_profiles = require("src.app.bootstrap.testing.config.test_profiles")

local resolver = {}
local default_map_module = "src.config.content.maps.default_map"

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

function resolver.available_profiles()
  return test_profiles.names()
end

function resolver.available_groups()
  return test_profiles.groups()
end

function resolver.profiles_in_group(group_name, opts)
  return test_profiles.profiles_in_group(group_name, opts)
end

return resolver
