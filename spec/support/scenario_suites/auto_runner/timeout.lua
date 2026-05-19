local gameplay_cases = require("spec.support.scenario_suites.shared.cases")

local function _case(name, overrides)
  local case = {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
  for key, value in pairs(overrides or {}) do
    case[key] = value
  end
  return case
end

return {
  name = "gameplay_timeout_and_auto_runner",
  tests = {
    _case("_test_autorunner_runs_to_end"),
    _case("_test_action_button_timeout_auto_advances"),
    _case("_test_action_button_timeout_manual_wait_action_auto_advances"),
    _case("_test_action_button_timeout_manual_player_does_not_advance"),
    _case("_test_action_button_timeout_blocked_when_input_locked"),
    _case("_test_action_button_timeout_blocked_when_popup_active"),
    _case("_test_auto_runner_auto_advances_ai_player"),
    _case("_test_auto_runner_human_turn_not_auto_advanced"),
    _case("_test_auto_runner_waits_for_auto_popup_delay"),
    _case("_test_gameplay_loop_ai_rounds_do_not_force_manual_timeout"),
    _case("_test_auto_runner_choice_actor_falls_back_to_choice_owner"),
    _case("_test_auto_runner_modal_without_buttons_confirms"),
    _case("_test_auto_runner_not_advanced_when_input_blocked"),
    _case("_test_auto_runner_depends_on_current_player_auto"),
    _case("_test_tick_choice_timeout_manual_player_keeps_waiting"),
    _case("_test_tick_ui_sync_countdown_hides_manual_pending_choice_timeout"),
    _case("_test_tick_choice_timeout_warning_ignores_non_modal_or_non_local_choice"),
    _case("_test_tick_choice_timeout_warning_keeps_local_modal_choice"),
    _case("_test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy"),
    _case("_test_popup_countdown_uses_effective_modal_timeout"),
    _case("_test_market_countdown_uses_double_action_timeout"),
    _case("_test_dispatch_gate_blocks_next_when_choice_active"),
    _case("_test_fill_ui_sync_defaults_fills_all"),
    _case("_test_fill_ui_sync_defaults_preserves_custom"),
    _case("_test_fill_ui_sync_defaults_resolve_ui_gate"),
    _case("_test_fill_ui_sync_defaults_set_input_blocked"),
    _case("_test_fill_ui_sync_defaults_gate_nil_state"),
    _case("_test_update_countdown_pending_choice"),
    _case("_test_update_countdown_detained_wait"),
    _case("_test_update_countdown_action_button"),
    _case("_test_update_countdown_popup_zero_timeout"),
    _case("_test_is_action_button_wait_active_pending_choice"),
    _case("_test_is_action_button_wait_active_input_blocked"),
    _case("_test_is_action_button_wait_active_popup"),
    _case("_test_is_action_button_wait_active_finished_game"),
    _case("_test_choice_auto_policy_preconsumed_wait_choice_picks_first_option"),
    _case("_test_turn_timer_policy_detained_wait_steps_when_timeout_elapsed"),
    _case("_test_turn_timer_policy_inter_turn_wait_steps_when_timeout_elapsed"),
    _case("_test_item_slot_data_prefers_role_specific_items_and_falls_back"),
    _case("_test_gameplay_loop_ports_rejects_legacy_flat_override"),
    _case("_test_build_noop_group_characterization"),
    _case("_test_decision_engine_cancels_item_phase_passive"),
  },
}
