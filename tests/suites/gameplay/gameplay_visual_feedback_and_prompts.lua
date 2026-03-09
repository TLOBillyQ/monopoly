local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_visual_feedback_and_prompts", {
  "_test_tick_headless_ports_cover_anim_phases",
  "_test_turn_prompt_initialized_for_first_player",
  "_test_turn_prompt_emitted_on_next_player_switch",
})
