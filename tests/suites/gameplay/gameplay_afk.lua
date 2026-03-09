local gameplay_cases = require("suites.gameplay.gameplay_cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay_afk",
  tests = {
    _case("_test_afk_auto_host_enters_auto_after_timeout_in_start_phase"),
    _case("_test_afk_auto_host_enters_auto_after_timeout_in_wait_choice"),
    _case("_test_afk_auto_host_next_input_resets_timer"),
    _case("_test_afk_auto_host_market_tab_input_resets_timer"),
    _case("_test_afk_auto_host_does_not_accumulate_when_input_locked"),
    _case("_test_afk_auto_host_does_not_accumulate_when_popup_active"),
    _case("_test_afk_auto_host_does_not_accumulate_in_wait_action_anim"),
    _case("_test_afk_auto_host_resets_when_current_player_changes"),
    _case("_test_afk_auto_host_enters_auto_after_timeout_in_action_wait_phase"),
    _case("_test_afk_auto_host_timeout_next_does_not_reset_timer"),
    _case("_test_afk_auto_host_timeout_next_accumulates_across_turns"),
  },
}
