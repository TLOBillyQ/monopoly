-- Quick regression checks (run with: lua tests/regression.lua)
package.path = "?.lua;?/init.lua;./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua;" .. package.path

local harness = require("TestHarness")

local suites = {
  require("chance"),
  require("land"),
  require("item"),
  require("movement"),
  require("landing"),
  require("market"),
  require("paid_currency"),
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
dofile("tests/internal/dep_rules.lua")
dofile("tests/internal/gameplay_loop_no_ui.lua")
