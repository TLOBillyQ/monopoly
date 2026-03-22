local base_suite = require("suites.architecture.crap_contract")

return {
  name = "crap_tooling_contract",
  tests = base_suite.tests or {},
}
