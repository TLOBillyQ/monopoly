local base_suite = require("suites.architecture.scrap4lua_contract")

return {
  name = "scrap4lua_tooling_contract",
  tests = base_suite.tooling_tests or {},
}
