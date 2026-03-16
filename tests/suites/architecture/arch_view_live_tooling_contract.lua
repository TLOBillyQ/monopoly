local base_suite = require("suites.architecture.arch_view_contract")

return {
  name = "arch_view_live_tooling_contract",
  tests = base_suite.tooling_tests or {},
}
