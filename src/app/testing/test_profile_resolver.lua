local test_profiles = require("src.app.testing.test_profiles")
local tables = require("src.foundation.tables")

local resolver = {}
local default_map_module = "src.config.content.default_map"

local function _join_profile_names(profile_names)
  return tables.join_or_default(profile_names, ", ", "default")
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

local function _resolve_profile(profile_name)
  local name = _resolve_name(profile_name)
  local profile = test_profiles.get(name)
  assert(profile ~= nil, "missing test profile: " .. tostring(name))
  return profile
end

function resolver.resolve_map(profile_name)
  _resolve_profile(profile_name)
  local ok, map_or_err = pcall(require, default_map_module)
  assert(ok, "failed to require default map module for profile " .. tostring(profile_name) .. ": " .. tostring(map_or_err))
  return map_or_err
end

function resolver.resolve_bootstrap(profile_name)
  local profile = _resolve_profile(profile_name)
  return profile.bootstrap
end

-- Returns the live-editor expectation table for a profile, or nil when the
-- profile carries no `expect`. Raises on an unknown profile, like the other
-- resolver accessors. Drives the e2e profile lane's runnable/skipped split.
function resolver.expect_for(profile_name)
  local profile = _resolve_profile(profile_name)
  return profile.expect
end

resolver.available_profiles = test_profiles.names
resolver.available_groups = test_profiles.groups
resolver.profiles_in_group = test_profiles.profiles_in_group

return resolver

--[[ mutate4lua-manifest
version=2
projectHash=047b30a2cf4b405d
scope.0.id=chunk:src/app/testing/test_profile_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=eb56e3a48f448db1
scope.0.lastMutatedAt=2026-06-02T08:41:31Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_join_profile_names:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=70b4d253e4458cae
scope.1.lastMutatedAt=2026-06-02T08:41:31Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_resolve_name:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=22
scope.2.semanticHash=ec017a7bb1dd1034
scope.2.lastMutatedAt=2026-06-02T08:41:31Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_resolve_profile:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=29
scope.3.semanticHash=c847b74c7013598b
scope.3.lastMutatedAt=2026-06-02T08:41:31Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:resolver.resolve_map:31
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=36
scope.4.semanticHash=ce7522f6b321a837
scope.4.lastMutatedAt=2026-06-02T08:41:31Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:resolver.resolve_bootstrap:38
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=41
scope.5.semanticHash=84b913c6caa5d592
scope.5.lastMutatedAt=2026-06-02T08:41:31Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:resolver.expect_for:46
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=49
scope.6.semanticHash=a0975ccbe2e5f8d1
scope.6.lastMutatedAt=2026-06-02T08:41:31Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
]]
