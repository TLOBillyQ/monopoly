local base_suite = require("spec.support.tooling_suites.architecture.script_tools_contract")

local names = {
  mutate_wrapper_scan_json_output = true,
  mutate_wrapper_indexes_behavior_suites_as_json = true,
}

local tests = {}

for _, test in ipairs(base_suite.tooling_tests or {}) do
  if names[test.name] == true then
    tests[#tests + 1] = test
  end
end

return {
  name = "script_tools_mutate_tooling_contract",
  tests = tests,
}
