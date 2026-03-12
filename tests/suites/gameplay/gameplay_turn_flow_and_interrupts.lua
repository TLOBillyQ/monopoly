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
    _case("_test_turn_script_dispatches_wait_states_and_move_followup_fallback"),
  },
}
