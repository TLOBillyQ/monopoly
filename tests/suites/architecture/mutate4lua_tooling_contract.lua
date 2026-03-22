local base_suite = require("suites.architecture.mutate4lua_contract")

return {
  name = "mutate4lua_tooling_contract",
  tests = base_suite.tests or {},
}
