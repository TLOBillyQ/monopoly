local gameplay_cases = require("spec.support.scenario_suites.shared.cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay.forced_relocation_and_followup",
  tests = {
    _case("_test_owner_mine_other_player_triggers_immediately_after_placement"),
    _case("_test_owner_mine_stays_immune_for_next_own_turn_then_triggers_on_third"),
    _case("_test_passing_armed_mine_stops_and_triggers_followup"),
    _case("_test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending"),
  },
}
