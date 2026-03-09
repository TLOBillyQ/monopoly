local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_bankruptcy_and_tile_owner", {
  "_test_mandatory_payment_causes_bankruptcy",
  "_test_bankruptcy_resets_owned_tiles",
  "_test_bankruptcy_notifier_reads_grouped_ports",
  "_test_gameplay_loop_set_game_installs_bankruptcy_feedback_port",
  "_test_bankruptcy_calls_role_life_die_before_lose",
  "_test_bankruptcy_emits_feedback_event",
  "_test_chance_pay_others_stops_after_bankruptcy",
  "_test_set_tile_owner_without_ui_port_does_not_crash",
  "_test_tile_owner_notifier_receives_owner_changes",
  "_test_owner_mine_does_not_trigger_until_owner_leaves_tile",
  "_test_owner_mine_triggers_again_after_placement_turn",
})
