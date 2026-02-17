-- Quick regression checks (run with: lua tests/regression.lua)
package.path = "?.lua;?/init.lua;./tests/?.lua;./tests/runner/?.lua;./tests/support/?.lua;./tests/specs/?.lua;./tests/specs/unit/?.lua;./tests/specs/contract/?.lua;./tests/specs/integration/?.lua;./tests/specs/regression/?.lua;./tests/fixtures/?.lua;" .. package.path

local runner = require("runner.init")

runner.run({
  include_internal = true,
})
