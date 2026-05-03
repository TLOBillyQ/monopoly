local raw_profiles = require("src.config.testing.test_profiles")
local tables = require("src.foundation.lang.tables")
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
}

local function _validate_profiles(profiles)
  assert(type(profiles) == "table", "invalid test profiles root")
  for profile_name, profile in pairs(profiles) do
    assert(type(profile_name) == "string", "invalid test profile name")
    assert(type(profile) == "table", "invalid test profile payload: " .. tostring(profile_name))
    assert(type(profile.group) == "string" and profile.group ~= "", "missing profile group: " .. tostring(profile_name))
    assert(type(profile.goal) == "string" and profile.goal ~= "", "missing profile goal: " .. tostring(profile_name))
    assert(valid_values[profile.value] == true, "invalid profile value: " .. tostring(profile_name))
    assert(type(profile.covers) == "table" and #profile.covers > 0, "missing profile covers: " .. tostring(profile_name))
    assert(type(profile.owner_tests) == "table" and #profile.owner_tests > 0,
      "missing profile owner_tests: " .. tostring(profile_name))
    if profile.bootstrap ~= nil then
      assert(type(profile.bootstrap) == "table", "invalid bootstrap payload: " .. tostring(profile_name))
    end
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
    if profile
        and profile.group == group_name
        and (opts.value == nil or profile.value == opts.value) then
      out[#out + 1] = name
    end
  end
  table.sort(out, _sort_names)
  return out
end

return M
