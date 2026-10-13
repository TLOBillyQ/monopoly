local gameplay_cases = require("test.support.scenario_suites.shared.cases")

return function(describe, it)
  describe("TestUiSyncPrompts", function()
    it("test__test_tick_headless_ports_cover_anim_phases", gameplay_cases._test_tick_headless_ports_cover_anim_phases)
    it("test__test_turn_prompt_emitted_on_next_player_switch", gameplay_cases._test_turn_prompt_emitted_on_next_player_switch)
    it("test__test_turn_prompt_initialized_for_first_player", gameplay_cases._test_turn_prompt_initialized_for_first_player)
  end)
end
