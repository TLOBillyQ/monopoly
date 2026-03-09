local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_runtime_context_and_camera_sync", {
  "_test_runtime_event_bridge_detects_unbound_binding_without_call",
  "_test_runtime_context_split_install_stages",
  "_test_runtime_context_install_helpers_without_globals",
  "_test_runtime_context_install_environment_fails_fast",
  "_test_game_startup_build_state_is_pure_and_bridge_installs_events",
  "_test_turn_dispatch_uses_clock_ports_without_game_api",
  "_test_gameplay_loop_set_game_uses_narrow_runtime_ports",
  "_test_gameplay_loop_refresh_drives_camera_follow_via_port",
  "_test_gameplay_loop_camera_follow_skips_eliminated_current_player",
  "_test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics",
  "_test_game_startup_role_roster_retries_before_debug_players_fallback",
  "_test_find_player_by_id_accepts_mixed_representation",
  "_test_runtime_context_change_skin_exports_and_event",
})
