local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_bankruptcy_and_tile_owner", {
  "_test_mandatory_payment_causes_bankruptcy",
  "_test_bankruptcy_resets_owned_tiles",
  "_test_bankruptcy_notifier_reads_grouped_ports",
  "_test_chance_pay_others_stops_after_bankruptcy",
  "_test_set_tile_owner_without_ui_port_does_not_crash",
  "_test_tile_owner_notifier_receives_owner_changes",
})
