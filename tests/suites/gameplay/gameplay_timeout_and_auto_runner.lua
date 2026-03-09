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
  "_test_profile_rotation_switches_game_after_turn_limit",
  "_test_profile_rotation_switches_game_when_current_game_finishes",
  "_test_profile_rotation_disables_auto_runner_after_last_profile",
  "_test_auto_runner_auto_advances_ai_player",
  "_test_auto_runner_human_turn_not_auto_advanced",
  "_test_auto_runner_not_advanced_when_input_blocked",
  "_test_auto_runner_depends_on_current_player_auto",
  "_test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy",
  "_test_popup_countdown_uses_effective_modal_timeout",
  "_test_market_countdown_uses_double_action_timeout",
  "_test_dispatch_gate_blocks_next_when_choice_active",
})
