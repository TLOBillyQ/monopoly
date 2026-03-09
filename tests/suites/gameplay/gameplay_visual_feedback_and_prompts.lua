local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_visual_feedback_and_prompts", {
  "_test_tick_headless_ports_cover_anim_phases",
  "_test_turn_prompt_initialized_for_first_player",
  "_test_turn_prompt_emitted_on_next_player_switch",
  "_test_turn_start_emits_turn_started_feedback_event",
  "_test_gameplay_loop_set_game_defers_visual_ports_during_landing_hold",
  "_test_board_visual_feedback_port_reconciles_destroyed_tile_and_cleared_overlays",
  "_test_board_visual_feedback_port_reconciles_spawned_tile_and_overlays_without_action_anim",
})
