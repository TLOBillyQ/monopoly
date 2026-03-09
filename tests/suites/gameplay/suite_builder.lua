local gameplay_cases = require("suites.gameplay.gameplay_cases")

local M = {}

local function _clone_table(source)
  local clone = {}
  for key, value in pairs(source or {}) do
    clone[key] = value
  end
  return clone
end

local function _build_case(case_name, overrides)
  local run = gameplay_cases[case_name]
  assert(type(run) == "function", "missing gameplay case: " .. tostring(case_name))
  local case = {
    name = case_name,
    run = run,
  }
  if overrides then
    for key, value in pairs(overrides) do
      if key == "disabled_in" or key == "tags" then
        case[key] = _clone_table(value)
      else
        case[key] = value
      end
    end
  end
  return case
end

function M.build_suite(suite_name, case_specs)
  local tests = {}
  for _, spec in ipairs(case_specs or {}) do
    if type(spec) == "string" then
      tests[#tests + 1] = _build_case(spec)
    else
      tests[#tests + 1] = _build_case(spec.name, spec)
    end
  end
  return {
    name = suite_name,
    tests = tests,
  }
end

return M
