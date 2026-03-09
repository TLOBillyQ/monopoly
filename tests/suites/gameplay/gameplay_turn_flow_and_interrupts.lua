local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_turn_flow_and_interrupts", {
  "_test_stop_all_players_movement_clears_move_dir_and_stop_event",
  "_test_end_turn_stops_all_players_movement",
  "_test_location_transfers_clear_move_dir",
  "_test_stop_all_players_movement_skips_invalid_role_without_error",
  "_test_complex_consecutive_turn_settlement",
  "_test_complex_market_interrupt_with_rent",
  "_test_market_interrupt_resume_uses_interrupt_facing",
  "_test_steal_interrupt_resume_uses_interrupt_facing",
  "_test_detained_turn_enters_wait_state_before_advancing",
})
