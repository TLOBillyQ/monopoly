local gameplay_cases = require("suites.gameplay.gameplay_cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay_runtime_context_and_camera_sync",
  tests = {
    _case("_test_runtime_event_bridge_detects_unbound_binding_without_call"),
    _case("_test_runtime_event_bridge_disables_feature_after_dispatch_failure"),
    _case("_test_runtime_context_split_install_stages"),
    _case("_test_runtime_context_install_helpers_without_globals"),
    _case("_test_runtime_context_release_helper_install_flow"),
    _case("_test_runtime_context_install_environment_fails_fast"),
    _case("_test_runtime_editor_exports_camera_target_returns_real_role_ctrl_unit"),
    _case("_test_runtime_editor_exports_camera_target_returns_synthetic_actor_unit"),
    _case("_test_runtime_editor_exports_camera_target_returns_nil_when_unit_unavailable"),
    _case("_test_game_startup_build_state_is_pure_and_bridge_installs_events"),
    _case("_test_turn_dispatch_uses_clock_ports_without_game_api"),
    _case("_test_gameplay_loop_set_game_uses_narrow_runtime_ports"),
    _case("_test_gameplay_loop_refresh_drives_camera_follow_via_port"),
    _case("_test_gameplay_loop_camera_follow_skips_eliminated_current_player"),
    _case("_test_gameplay_loop_clock_ports_split_wall_and_cpu_semantics"),
    _case("_test_game_startup_role_roster_retries_before_debug_players_fallback"),
    _case("_test_find_player_by_id_accepts_mixed_representation"),
    _case("_test_runtime_context_change_skin_exports_and_event"),
  },
}
