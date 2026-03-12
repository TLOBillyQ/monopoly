local gameplay_cases = require("suites.gameplay.gameplay_cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
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
    _case("_test_turn_script_dispatches_wait_states_and_move_followup_fallback"),
    _case("_test_camera_policy_follows_eliminated_then_skips_to_next"),
    _case("_test_camera_policy_follows_current_when_not_eliminated"),
    _case("_test_camera_policy_skips_all_eliminated_and_returns_nil"),
    _case("_test_choice_auto_policy_tick_timeout_cancels_when_allowed"),
    _case("_test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable"),
    _case("_test_choice_auto_policy_generic_mode_uses_fallback_flag"),
    _case("_test_roll_dice_with_override_uses_provided_values"),
    _case("_test_roll_dice_with_partial_override_uses_last_for_remaining"),
  },
}
