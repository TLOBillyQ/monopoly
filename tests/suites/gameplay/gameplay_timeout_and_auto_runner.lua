local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_timeout_and_auto_runner", {
  "_test_autorunner_runs_to_end",
  {
    name = "_test_action_button_timeout_auto_advances",
    disabled_in = {
      release_trimmed = true,
    },
  },
  "_test_action_button_timeout_blocked_when_input_locked",
  "_test_action_button_timeout_blocked_when_popup_active",
  "_test_auto_runner_auto_advances_ai_player",
  "_test_auto_runner_human_turn_not_auto_advanced",
  "_test_auto_runner_selects_runtime_pending_choice_without_ui_choice_screen",
  "_test_auto_runner_resets_timer_when_wait_kind_changes",
  "_test_auto_runner_not_advanced_when_input_blocked",
  "_test_tick_choice_timeout_uses_runtime_pending_choice_without_ui_choice_screen",
  "_test_tick_ui_sync_countdown_uses_runtime_pending_choice_without_ui_choice_screen",
  "_test_auto_runner_depends_on_current_player_auto",
  "_test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy",
  "_test_choice_auto_policy_timeout_keeps_non_cancelable_choice_fallback",
  "_test_turn_decision_wait_choice_no_longer_reads_ui_port_state",
  "_test_popup_countdown_uses_effective_modal_timeout",
  "_test_market_countdown_uses_double_action_timeout",
  "_test_dispatch_gate_blocks_next_when_choice_active",
})
