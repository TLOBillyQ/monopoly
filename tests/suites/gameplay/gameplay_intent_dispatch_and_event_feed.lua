local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_intent_dispatch_and_event_feed", {
  "_test_dispatch_validator_accepts_ui_state_snapshot",
  "_test_intent_dispatcher_sets_choice_route_metadata",
  "_test_intent_dispatcher_rejects_missing_required_choice_meta",
  "_test_intent_dispatcher_normalizes_market_choice_meta",
  "_test_intent_dispatcher_normalizes_item_choice_meta",
  "_test_intent_dispatcher_normalizes_landing_optional_effect_meta",
  "_test_intent_dispatcher_rejects_unknown_market_choice_player",
  "_test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile",
  "_test_turn_start_logs_phase_event_to_event_feed",
  "_test_intent_dispatcher_logs_waiting_choice_event",
  "_test_choice_resolver_normalizes_market_buy_action_before_execute",
  "_test_choice_resolver_normalizes_roadblock_action_before_execute",
  "_test_choice_cancel_logs_skip_event_but_tax_cancel_does_not",
  "_test_end_turn_logs_phase_event_to_event_feed",
  "_test_clear_obstacles_zero_does_not_log_event_noise",
  "_test_ai_obstacle_probe_does_not_enter_event_feed",
})
