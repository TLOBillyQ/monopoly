local gameplay_rules = require("Config.GameplayRules")
local test_profiles = require("Config.TestProfiles")

local default_module = "Config.Maps.DefaultMap"

local profile = test_profiles.resolve(gameplay_rules.test_profile)
local module_name = (profile and profile.map_module) or default_module

local ok, map_cfg = pcall(require, module_name)
if ok then
  return map_cfg
end

if module_name ~= default_module then
  return require(default_module)
end

error(map_cfg)
