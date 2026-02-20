-- Quick regression checks (run with: lua .github/tests/regression.lua)
package.path = package.path
  .. ";./.github/tests/?.lua;./.github/tests/suites/?.lua;./.github/tests/fixtures/?.lua"
  .. ";./.agents/tests/?.lua;./.agents/tests/suites/?.lua;./.agents/tests/fixtures/?.lua"

local harness = require("TestHarness")

local suites = {
  require("chance"),
  require("land"),
  require("item"),
  require("movement"),
  require("landing"),
  require("market"),
  require("paid_currency"),
  require("test_profiles"),
  require("presentation_ui_timing_anim"),
  require("presentation_ui_model_dispatch"),
  require("presentation_ui_interaction"),
  require("presentation_ui_popup_market"),
  require("presentation_ui_action_status"),
  require("presentation_ui_action_anim"),
  require("gameplay_core"),
  require("gameplay_runtime"),
  require("gameplay_loop"),
  require("misc"),
}

harness.run_all(suites)
dofile(".github/tests/internal/dep_rules.lua")
dofile(".github/tests/internal/gameplay_loop_no_ui.lua")
