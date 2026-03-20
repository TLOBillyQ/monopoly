local gameplay_cases = require("suites.gameplay.gameplay_cases")
local t2_enabled_cases = require("suites.gameplay.gameplay_t2_enabled_cases")

local function _case(name)
  local run = gameplay_cases[name] or t2_enabled_cases[name]
  return {
    name = name,
    run = assert(run, "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay_turn_flow_and_interrupts",
  tests = {
    _case("_test_complex_consecutive_turn_settlement"),
    _case("_test_complex_market_interrupt_with_rent"),
    _case("_test_turn_start_waits_for_pre_action_item_phase_choice"),
    _case("_test_turn_start_waits_for_pre_action_item_phase_action_anim"),
    _case("_test_phase_registry_post_action_routes_wait_variants"),
    _case("_test_turn_land_waits_for_move_followup_when_move_effect_queue_pending"),
    _case("_test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice"),
    _case("_test_roadblock_stop_does_not_detain_next_turn"),
    _case("_test_turn_script_dispatches_wait_states_and_move_followup_fallback"),
    _case("_test_camera_policy_follows_eliminated_then_skips_to_next"),
    _case("_test_camera_policy_follows_current_when_not_eliminated"),
    _case("_test_camera_policy_skips_all_eliminated_and_returns_nil"),
    _case("_test_choice_auto_policy_tick_timeout_cancels_when_allowed"),
    _case("_test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable"),
    _case("_test_choice_auto_policy_generic_mode_uses_fallback_flag"),
    _case("_test_roll_dice_with_override_uses_provided_values"),
    _case("_test_roll_dice_with_partial_override_uses_last_for_remaining"),
    _case("_test_roll_dice_with_rng_only"),
    _case("_test_roll_dice_zero_count"),
    _case("_test_roll_dice_truncates_extra_overrides"),
    _case("_test_roll_dice_exact_override_match"),
    _case("_test_apply_dice_multiplier_applies_and_resets"),
    _case("_test_apply_dice_multiplier_skips_when_total_changed"),
    _case("_test_apply_dice_multiplier_skips_when_raw_total_nil"),
    _case("_test_resolve_phase_wait_result_with_wait_action_anim"),
    _case("_test_resolve_phase_wait_result_without_wait_action_anim"),
    _case("_test_resolve_phase_wait_result_defaults"),
    _case("_test_resolve_wait_state_prefers_wait_action_anim"),
    _case("_test_resolve_wait_state_without_anim_returns_wait_choice"),
    _case("_test_resolve_wait_state_wraps_move_effect_queue"),
    _case("_test_validate_choice_actor_match"),
    _case("_test_validate_choice_actor_mismatch"),
    _case("_test_validate_choice_actor_no_owner"),
    _case("_test_validate_choice_actor_no_actor_id"),
    _case("_test_log_missing_auto_choice_action_logs_once"),
    _case("_test_log_missing_auto_choice_action_skips_when_waiting"),
    _case("_test_log_missing_auto_choice_action_skips_when_not_auto"),
    _case("_test_resolve_choice_owner_id_fallback_current"),
    _case("_test_resolve_choice_owner_id_out_of_range"),
    _case("_test_resolve_choice_owner_missing_find_player"),
    _case("_test_resolve_choice_owner_no_players"),
    _case("_test_resolve_follow_player_id_skip_nil_id"),
    _case("_test_resolve_follow_player_id_wrap_around"),
    _case("_test_resolve_follow_player_id_all_eliminated"),
    _case("_test_resolve_follow_player_id_nil_turn"),
    _case("_test_resolve_follow_player_id_empty_players"),
  },
}
