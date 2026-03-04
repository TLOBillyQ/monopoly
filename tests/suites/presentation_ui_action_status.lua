local registry = require("presentation_ui_registry")
local all = require("presentation_ui")

local suite = registry.slice("presentation_ui.action_status", 54, 91)

suite.tests[#suite.tests + 1] = {
  name = "_test_turn_effects_sync_restores_client_role_nil",
  run = assert(all[95], "missing presentation_ui test at index 95"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_popup_renderer_switch_popup_canvas_restores_client_role_nil",
  run = assert(all[96], "missing presentation_ui test at index 96"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_market_modal_renderer_open_restores_client_role_nil",
  run = assert(all[97], "missing presentation_ui test at index 97"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_debug_ports_sync_restores_client_role_nil",
  run = assert(all[98], "missing presentation_ui test at index 98"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_status3d_hospital_visible_when_detained_turn_even_if_stay_turns_zero",
  run = assert(all[105], "missing presentation_ui test at index 105"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_status3d_mountain_visible_when_detained_turn_even_if_stay_turns_zero",
  run = assert(all[106], "missing presentation_ui test at index 106"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero",
  run = assert(all[107], "missing presentation_ui test at index 107"),
}

return suite
