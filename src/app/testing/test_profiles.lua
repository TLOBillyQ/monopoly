local raw_profiles = require("src.config.test_profiles")
local tables = require("src.foundation.tables")
local M = {}
local default_profile = {
  group = "startup_smoke",
  goal = "baseline_startup_and_roster",
  value = "smoke",
  covers = { "startup", "roster", "render_bootstrap" },
  owner_tests = { "runtime.startup_profile" },
  bootstrap = {},
}
local valid_values = {
  smoke = true,
  core = true,
  edge = true,
}
local group_order = {
  startup_smoke = 1,
  combat_obstacle = 2,
  relocation_status = 3,
  interrupt_resume = 4,
  property_control = 5,
  economy_core = 6,
  commerce_paid = 7,
}

local function _validate_required_fields(profile_name, profile)
  assert(type(profile) == "table", "invalid test profile payload: " .. tostring(profile_name))
  assert(type(profile.group) == "string" and profile.group ~= "", "missing profile group: " .. tostring(profile_name))
  assert(type(profile.goal) == "string" and profile.goal ~= "", "missing profile goal: " .. tostring(profile_name))
  assert(valid_values[profile.value] == true, "invalid profile value: " .. tostring(profile_name))
end

local function _validate_collection_fields(profile_name, profile)
  assert(type(profile.covers) == "table" and #profile.covers > 0, "missing profile covers: " .. tostring(profile_name))
  assert(type(profile.owner_tests) == "table" and #profile.owner_tests > 0,
    "missing profile owner_tests: " .. tostring(profile_name))
end

local function _validate_profile_fields(profile_name, profile)
  _validate_required_fields(profile_name, profile)
  _validate_collection_fields(profile_name, profile)
  if profile.bootstrap ~= nil then
    assert(type(profile.bootstrap) == "table", "invalid bootstrap payload: " .. tostring(profile_name))
  end
end

local function _validate_profiles(profiles)
  assert(type(profiles) == "table", "invalid test profiles root")
  for profile_name, profile in pairs(profiles) do
    assert(type(profile_name) == "string", "invalid test profile name")
    _validate_profile_fields(profile_name, profile)
  end
  return profiles
end

local profiles = _validate_profiles(raw_profiles)

local function _all_profile_names(include_default)
  local out = {}
  if include_default ~= false then
    out[#out + 1] = "default"
  end
  for name in pairs(profiles) do
    out[#out + 1] = name
  end
  return out
end

local function _profile_for_name(name)
  if name == "default" then
    return default_profile
  end
  return profiles[name]
end

local function _group_sort_key(profile)
  return group_order[profile.group] or 999
end

local function _sort_names(left, right)
  local left_profile = _profile_for_name(left) or default_profile
  local right_profile = _profile_for_name(right) or default_profile
  local left_group = _group_sort_key(left_profile)
  local right_group = _group_sort_key(right_profile)
  if left_group ~= right_group then
    return left_group < right_group
  end
  return left < right
end

function M.resolve(profile_name)
  if type(profile_name) ~= "string" or profile_name == "" or profile_name == "default" then
    return tables.copy(default_profile)
  end
  return tables.copy(profiles[profile_name] or default_profile)
end

function M.has(profile_name)
  return profile_name == "default" or (type(profile_name) == "string" and profiles[profile_name] ~= nil)
end

function M.get(profile_name)
  if profile_name == "default" then
    return tables.copy(default_profile)
  end
  if not M.has(profile_name) then
    return nil
  end
  return tables.copy(profiles[profile_name])
end

function M.names()
  local out = _all_profile_names(true)
  table.sort(out, _sort_names)
  return out
end

function M.groups()
  local seen = {
    [default_profile.group] = true,
  }
  for _, profile in pairs(profiles) do
    seen[profile.group] = true
  end
  local out = {}
  for name in pairs(seen) do
    out[#out + 1] = name
  end
  table.sort(out, function(left, right)
    local left_order = group_order[left] or 999
    local right_order = group_order[right] or 999
    if left_order ~= right_order then
      return left_order < right_order
    end
    return left < right
  end)
  return out
end

function M.profiles_in_group(group_name, opts)
  opts = opts or {}
  local out = {}
  for _, name in ipairs(_all_profile_names(opts.include_default ~= false)) do
    local profile = _profile_for_name(name)
    if profile and profile.group == group_name and (opts.value == nil or profile.value == opts.value) then
      out[#out + 1] = name
    end
  end
  table.sort(out, _sort_names)
  return out
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=e6a2102974ce0834
scope.0.id=chunk:src/app/testing/test_profiles.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=143
scope.0.semanticHash=ade6441c892d04d0
scope.1.id=function:_profile_for_name:58
scope.1.kind=function
scope.1.startLine=58
scope.1.endLine=63
scope.1.semanticHash=ee2b129f7b8bb083
scope.2.id=function:_group_sort_key:65
scope.2.kind=function
scope.2.startLine=65
scope.2.endLine=67
scope.2.semanticHash=a56c654f5564c72f
scope.3.id=function:_sort_names:69
scope.3.kind=function
scope.3.startLine=69
scope.3.endLine=78
scope.3.semanticHash=ee9b72f3b1991527
scope.4.id=function:M.resolve:80
scope.4.kind=function
scope.4.startLine=80
scope.4.endLine=85
scope.4.semanticHash=838c7d6e7f77f89b
scope.5.id=function:M.has:87
scope.5.kind=function
scope.5.startLine=87
scope.5.endLine=89
scope.5.semanticHash=1a31664915dd50c6
scope.6.id=function:M.get:91
scope.6.kind=function
scope.6.startLine=91
scope.6.endLine=99
scope.6.semanticHash=fa74a9b0b2a73276
scope.7.id=function:M.names:101
scope.7.kind=function
scope.7.startLine=101
scope.7.endLine=105
scope.7.semanticHash=d4fc05c3cd79601d
scope.8.id=function:anonymous@118:118
scope.8.kind=function
scope.8.startLine=118
scope.8.endLine=125
scope.8.semanticHash=506352134ef42535
]]
