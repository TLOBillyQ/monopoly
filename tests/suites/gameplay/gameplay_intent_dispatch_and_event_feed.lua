local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_intent_dispatch_and_event_feed", {
  "_test_dispatch_validator_accepts_ui_state_snapshot",
  "_test_intent_dispatcher_sets_choice_route_metadata",
  "_test_intent_dispatcher_sets_choice_route_metadata",
})
