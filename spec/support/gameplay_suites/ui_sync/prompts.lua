local gameplay_cases = require("spec.support.gameplay_suites.shared.cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay_visual_feedback_and_prompts",
  tests = {
    _case("_test_tick_headless_ports_cover_anim_phases"),
    _case("_test_turn_prompt_initialized_for_first_player"),
    _case("_test_turn_prompt_emitted_on_next_player_switch"),
  },
}
