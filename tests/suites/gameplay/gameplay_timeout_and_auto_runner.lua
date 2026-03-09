local gameplay_cases = require("suites.gameplay.gameplay_cases")

local function _case(name, overrides)
  local case = {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
  for key, value in pairs(overrides or {}) do
    case[key] = value
  end
  return case
end

return {
  name = "gameplay_timeout_and_auto_runner",
  tests = {
    _case("_test_autorunner_runs_to_end"),
    _case("_test_action_button_timeout_auto_advances", {
      disabled_in = {
        release_trimmed = true,
      },
    }),
    _case("_test_action_button_timeout_blocked_when_input_locked"),
    _case("_test_action_button_timeout_blocked_when_popup_active"),
    _case("_test_profile_rotation_switches_game_after_turn_limit"),
    _case("_test_profile_rotation_switches_game_when_current_game_finishes"),
    _case("_test_profile_rotation_disables_auto_runner_after_last_profile"),
    _case("_test_auto_runner_auto_advances_ai_player"),
    _case("_test_auto_runner_human_turn_not_auto_advanced"),
    _case("_test_auto_runner_not_advanced_when_input_blocked"),
    _case("_test_auto_runner_depends_on_current_player_auto"),
    _case("_test_choice_auto_policy_wait_and_timeout_both_cancel_market_buy"),
    _case("_test_popup_countdown_uses_effective_modal_timeout"),
    _case("_test_market_countdown_uses_double_action_timeout"),
    _case("_test_dispatch_gate_blocks_next_when_choice_active"),
  },
}
