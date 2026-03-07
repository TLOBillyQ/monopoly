local registry = require("suites.presentation.registry")
local all = require("presentation.presentation_ui")

local suite = registry.slice("presentation_ui.action_status", 53, 107)

suite.tests[#suite.tests + 1] = {
  name = "_test_turn_effects_sync_restores_client_role_nil",
  run = assert(all[111], "missing presentation_ui test at index 111"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_popup_renderer_switch_popup_canvas_restores_client_role_nil",
  run = assert(all[112], "missing presentation_ui test at index 112"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_market_modal_renderer_open_restores_client_role_nil",
  run = assert(all[113], "missing presentation_ui test at index 113"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_debug_ports_sync_restores_client_role_nil",
  run = assert(all[114], "missing presentation_ui test at index 114"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_status3d_hospital_visible_when_detained_turn_even_if_stay_turns_zero",
  run = assert(all[115], "missing presentation_ui test at index 115"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_status3d_mountain_visible_when_detained_turn_even_if_stay_turns_zero",
  run = assert(all[116], "missing presentation_ui test at index 116"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_status3d_hospital_mountain_not_visible_when_not_detained_and_stay_turns_zero",
  run = assert(all[117], "missing presentation_ui test at index 117"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_action_log_uses_cached_local_role_when_event_role_missing",
  run = assert(all[118], "missing presentation_ui test at index 118"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_auto_uses_cached_local_role_instead_of_current_player",
  run = assert(all[119], "missing presentation_ui test at index 119"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_state_resolve_debug_enabled_supports_mixed_role_id_keys",
  run = assert(all[120], "missing presentation_ui test at index 120"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_market_view_unbuyable_option_is_clickable",
  run = assert(all[121], "missing presentation_ui test at index 121"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_market_view_hides_disabled_market_tab",
  run = assert(all[122], "missing presentation_ui test at index 122"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_market_view_page_arrows_visibility_follows_page_count",
  run = assert(all[123], "missing presentation_ui test at index 123"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_modal_presenter_market_same_choice_id_still_refreshes_market_panel",
  run = assert(all[124], "missing presentation_ui test at index 124"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_market_cancel_button_dispatches_choice_cancel",
  run = assert(all[125], "missing presentation_ui test at index 125"),
}

return suite
