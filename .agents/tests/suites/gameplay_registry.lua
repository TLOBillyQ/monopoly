local names = {
  "_test_mandatory_payment_causes_bankruptcy",
  "_test_bankruptcy_resets_owned_tiles",
  "_test_set_tile_owner_without_ui_port_does_not_crash",
  "_test_tile_owner_notifier_receives_owner_changes",
  "_test_dispatch_validator_accepts_ui_state_snapshot",
  "_test_stop_all_players_movement_clears_move_dir_and_stop_event",
  "_test_end_turn_stops_all_players_movement",
  "_test_stop_all_players_movement_skips_invalid_role_without_error",
  "_test_runtime_context_get_vehicle_player_no_fallback",
  "_test_runtime_context_forward_stop_skips_invalid_role",
  "_test_runtime_context_split_install_stages",
  "_test_runtime_context_install_environment_fails_fast",
  "_test_set_player_seat_emits_exit_then_enter",
  "_test_mine_destroy_vehicle_emits_exit_event",
  "_test_vehicle_feature_disabled_ignores_seat_bonus",
  "_test_turn_move_anim_omits_vehicle_id_when_disabled",
  "_test_autorunner_runs_to_end",
  "_test_complex_consecutive_turn_settlement",
  "_test_complex_market_interrupt_with_rent",
  "_test_tick_headless_ports_cover_anim_phases",
  "_test_action_button_timeout_auto_advances",
  "_test_action_button_timeout_blocked_when_input_locked",
  "_test_action_button_timeout_blocked_when_popup_active",
  "_test_auto_runner_auto_advances_ai_player",
  "_test_auto_runner_human_turn_not_auto_advanced",
  "_test_auto_runner_not_advanced_when_input_blocked",
  "_test_auto_runner_depends_on_current_player_auto",
  "_test_turn_prompt_initialized_for_first_player",
  "_test_turn_prompt_emitted_on_next_player_switch",
}

local function slice(suite_name, first_index, last_index)
  local all = require("gameplay")
  local selected = {}
  for index = first_index, last_index do
    local run = all[index]
    assert(type(run) == "function", "missing gameplay test at index " .. tostring(index))
    selected[#selected + 1] = {
      name = names[index] or ("gameplay_test_" .. tostring(index)),
      run = run,
    }
  end
  return {
    name = suite_name,
    tests = selected,
  }
end

return {
  slice = slice,
}
