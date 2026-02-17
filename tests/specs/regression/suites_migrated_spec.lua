local function _normalize_suite(suite, fallback_name)
  if suite and suite.tests then
    return suite.name or fallback_name, suite.tests
  end
  return fallback_name, suite or {}
end

local function _normalize_case(case_def, case_index)
  if type(case_def) == "function" then
    return "case_" .. tostring(case_index), case_def
  end
  if type(case_def) == "table" and type(case_def.run) == "function" then
    return case_def.name or ("case_" .. tostring(case_index)), case_def.run
  end
  error("invalid case at index " .. tostring(case_index))
end

local function _build_spec(module_name)
  local suite = require(module_name)
  local suite_name, tests = _normalize_suite(suite, module_name)
  local cases = {}
  for case_index, case_def in ipairs(tests) do
    local case_name, run = _normalize_case(case_def, case_index)
    cases[#cases + 1] = {
      id = suite_name .. "." .. case_name,
      desc = "migrated suite " .. suite_name .. "." .. case_name,
      run = run,
    }
  end
  return {
    layer = "regression",
    domain = "suite_" .. module_name,
    cases = cases,
  }
end

local modules = {
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

local specs = {}
for _, module_name in ipairs(modules) do
  specs[#specs + 1] = _build_spec(module_name)
end

return specs
