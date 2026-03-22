local base_suite = require("suites.architecture.script_tools_contract")

local names = {
  deploy_comprehensive = true,
  run_command_preserves_bilingual_stderr_and_utf8_stdin = true,
}

local tests = {}

for _, test in ipairs(base_suite.tooling_tests or {}) do
  if names[test.name] == true then
    tests[#tests + 1] = test
  end
end

return {
  name = "script_tools_process_tooling_contract",
  tests = tests,
}
