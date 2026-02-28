-- Quick regression checks (run with: lua .agents/tests/regression.lua)
package.path = package.path
  .. ";./.agents/tests/?.lua;./.agents/tests/suites/?.lua;./.agents/tests/fixtures/?.lua"
  .. ";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"

local function dofile_first(paths)
  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      f:close()
      dofile(path)
      return
    end
  end
  error("missing internal script: " .. table.concat(paths, ", "))
end

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
  require("presentation_ui_event_bindings"),
  require("gameplay_core"),
  require("gameplay_runtime"),
  require("gameplay_coroutine"),
  require("gameplay_loop"),
  require("misc"),
}

harness.run_all(suites)
dofile_first({".agents/tests/internal/dep_rules.lua", "tests/internal/dep_rules.lua"})
dofile_first({
  ".agents/tests/internal/gameplay_loop_no_ui.lua",
  "tests/internal/gameplay_loop_no_ui.lua",
})
