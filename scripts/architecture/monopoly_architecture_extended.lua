local base = dofile("scripts/architecture/monopoly_architecture.lua")

local function _copy_array(values)
  local out = {}
  for _, value in ipairs(values or {}) do
    out[#out + 1] = value
  end
  return out
end

local function _copy_rules(values)
  local out = {}
  for _, rule in ipairs(values or {}) do
    local copy = {}
    for key, value in pairs(rule) do
      if type(value) == "table" then
        copy[key] = _copy_array(value)
      else
        copy[key] = value
      end
    end
    out[#out + 1] = copy
  end
  return out
end

local config = {
  source_roots = { "src", "tests", "scripts" },
  component_rules = _copy_rules(base.component_rules),
  abstract_rules = _copy_rules(base.abstract_rules),
  forbidden_dependency_rules = _copy_rules(base.forbidden_dependency_rules),
  cycle_baseline = _copy_array(base.cycle_baseline),
}

config.component_rules[#config.component_rules + 1] = {
  name = "tests",
  match = { "^tests$", "^tests%..+" },
  component = "tests",
}

config.component_rules[#config.component_rules + 1] = {
  name = "architecture_scripts",
  match = { "^scripts%.architecture$", "^scripts%.architecture%..+" },
  component = "architecture_scripts",
}

config.component_rules[#config.component_rules + 1] = {
  name = "quality_scripts",
  match = { "^scripts%.quality$", "^scripts%.quality%..+" },
  component = "quality_scripts",
}

return config
