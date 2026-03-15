local base_suite = require("suites.architecture.script_tools_contract")

return {
  name = "script_tools_tooling_contract",
  tests = base_suite.tooling_tests or {},
}
