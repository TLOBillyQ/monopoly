-- Quick regression checks (run with: lua .agents/tests/regression.lua)
package.path = package.path .. ";./.agents/tests/?.lua;./.agents/tests/suites/?.lua"

local harness = require("TestHarness")

local suites = {
  require("chance"),
  require("land"),
  require("item"),
  require("movement"),
  require("landing"),
  require("market"),
  require("paid_currency"),
  require("presentation_ui"),
  require("gameplay"),
  require("misc"),
}

harness.run_all(suites)
