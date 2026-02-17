local legacy_adapter = {}

local function _normalize_suite(suite, suite_index, fallback_name)
  if suite and suite.tests then
    return suite.name or ("suite_" .. tostring(suite_index)), suite.tests
  end
  return fallback_name or ("suite_" .. tostring(suite_index)), suite or {}
end

local function _normalize_case(case_def, case_index, suite_name)
  if type(case_def) == "function" then
    return "case_" .. tostring(case_index), case_def
  end
  if type(case_def) == "table" and type(case_def.run) == "function" then
    return case_def.name or ("case_" .. tostring(case_index)), case_def.run
  end
  error("invalid test case in " .. tostring(suite_name) .. " at index " .. tostring(case_index))
end

local function _legacy_suite_modules()
  return {
    "chance",
    "land",
    "item",
    "movement",
    "landing",
    "market",
    "paid_currency",
    "presentation_ui",
    "presentation_ui_action_anim",
    "gameplay",
    "misc",
  }
end

local function _build_case(layer, domain, suite_name, case_name, run)
  local id = suite_name .. "." .. case_name
  return {
    layer = layer,
    domain = domain,
    id = id,
    desc = "legacy " .. id,
    run = run,
  }
end

function legacy_adapter.collect_legacy_specs()
  local specs = {}
  for _, module_name in ipairs(_legacy_suite_modules()) do
    local suite = require(module_name)
    local suite_name, tests = _normalize_suite(suite, module_name, module_name)
    local cases = {}
    for case_index, case_def in ipairs(tests) do
      local case_name, run = _normalize_case(case_def, case_index, suite_name)
      cases[#cases + 1] = _build_case("legacy", module_name, suite_name, case_name, run)
    end
    specs[#specs + 1] = {
      layer = "legacy",
      domain = module_name,
      cases = cases,
    }
  end
  return specs
end

function legacy_adapter.run_legacy_internal_scripts()
  dofile("tests/internal/dep_rules.lua")
  dofile("tests/internal/gameplay_loop_no_ui.lua")
end

return legacy_adapter
