local support = require("support.regression_support")
local runtime_cases = require("support.regression.runtime_context_cases")
local autorunner_cases = require("support.regression.gameplay_autorunner_cases")
local core_cases = require("support.regression.gameplay_core_cases")
local loop_cases = require("support.regression.gameplay_loop_cases")

local _tests = {
  core_cases.test_mandatory_payment_causes_bankruptcy,
  core_cases.test_bankruptcy_resets_owned_tiles,
  core_cases.test_set_tile_owner_without_ui_port_does_not_crash,
  core_cases.test_tile_owner_notifier_receives_owner_changes,
  core_cases.test_dispatch_validator_accepts_ui_state_snapshot,
  core_cases.test_stop_all_players_movement_clears_move_dir_and_stop_event,
  core_cases.test_end_turn_stops_all_players_movement,
  core_cases.test_stop_all_players_movement_skips_invalid_role_without_error,
  runtime_cases.test_runtime_context_get_vehicle_player_no_fallback,
  runtime_cases.test_runtime_context_forward_stop_skips_invalid_role,
  runtime_cases.test_runtime_context_split_install_stages,
  runtime_cases.test_runtime_context_install_environment_fails_fast,
  core_cases.test_set_player_seat_emits_exit_then_enter,
  core_cases.test_mine_destroy_vehicle_emits_exit_event,
  core_cases.test_vehicle_feature_disabled_ignores_seat_bonus,
  core_cases.test_turn_move_anim_omits_vehicle_id_when_disabled,
  autorunner_cases.test_autorunner_runs_to_end,
  autorunner_cases.test_complex_consecutive_turn_settlement,
  autorunner_cases.test_complex_market_interrupt_with_rent,
  loop_cases.test_tick_headless_ports_cover_anim_phases,
  loop_cases.test_action_button_timeout_auto_advances,
  loop_cases.test_action_button_timeout_blocked_when_input_locked,
  loop_cases.test_action_button_timeout_blocked_when_popup_active,
  loop_cases.test_auto_runner_auto_advances_ai_player,
  loop_cases.test_auto_runner_human_turn_not_auto_advanced,
  loop_cases.test_auto_runner_not_advanced_when_input_blocked,
  loop_cases.test_auto_runner_depends_on_current_player_auto,
  loop_cases.test_turn_prompt_initialized_for_first_player,
  loop_cases.test_turn_prompt_emitted_on_next_player_switch,
}

local _cases = {}
for index, run in ipairs(_tests) do
  _cases[#_cases + 1] = {
    id = "gameplay.case_" .. tostring(index),
    desc = "gameplay migrated case " .. tostring(index),
    run = run,
  }
end

return {
  layer = "regression",
  domain = "gameplay",
  cases = _cases,
}
