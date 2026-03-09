local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_afk", {
  "_test_afk_auto_host_enters_auto_after_timeout_in_start_phase",
  "_test_afk_auto_host_enters_auto_after_timeout_in_wait_choice",
  "_test_afk_auto_host_next_input_resets_timer",
  "_test_afk_auto_host_market_tab_input_resets_timer",
  "_test_afk_auto_host_does_not_accumulate_when_input_locked",
  "_test_afk_auto_host_does_not_accumulate_when_popup_active",
  "_test_afk_auto_host_does_not_accumulate_in_wait_action_anim",
  "_test_afk_auto_host_resets_when_current_player_changes",
  "_test_afk_auto_host_enters_auto_after_timeout_in_action_wait_phase",
  "_test_afk_auto_host_timeout_next_does_not_reset_timer",
  "_test_afk_auto_host_timeout_next_accumulates_across_turns",
})
