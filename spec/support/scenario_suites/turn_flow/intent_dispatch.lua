local gameplay_cases = require("spec.support.scenario_suites.shared.cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay_intent_dispatch_and_event_feed",
  tests = {
    _case("_test_dispatch_validator_accepts_ui_state_snapshot"),
    _case("_test_intent_dispatcher_sets_choice_route_metadata"),
    _case("_test_intent_dispatcher_rejects_missing_required_choice_meta"),
    _case("_test_intent_dispatcher_rejects_missing_required_choice_meta_table"),
    _case("_test_intent_dispatcher_normalizes_market_choice_meta"),
    _case("_test_intent_dispatcher_normalizes_item_choice_meta"),
    _case("_test_intent_dispatcher_normalizes_landing_optional_effect_meta"),
    _case("_test_intent_dispatcher_rejects_unknown_market_choice_player"),
    _case("_test_intent_dispatcher_rejects_unknown_landing_optional_effect_tile"),
    _case("_test_turn_start_logs_phase_event_to_event_feed"),
    _case("_test_intent_dispatcher_logs_waiting_choice_event"),
    _case("_test_intent_dispatcher_dispatches_descriptor_meta_validator_without_required_keys"),
    _case("_test_intent_dispatcher_allows_missing_choice_registry"),
    _case("_test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload"),
    _case("_test_choice_cancel_logs_skip_event_but_tax_cancel_does_not"),
    _case("_test_end_turn_logs_phase_event_to_event_feed"),
    _case("_test_clear_obstacles_zero_does_not_log_event_noise"),
    _case("_test_ai_obstacle_probe_does_not_enter_event_feed"),
    _case("_test_ai_board_target_choice_falls_back_to_first_option"),
  },
}
