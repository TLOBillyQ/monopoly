local gameplay_cases = require("suites.gameplay.gameplay_cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay.forced_relocation_and_followup",
  tests = {
    _case("_test_owner_mine_does_not_trigger_until_owner_leaves_tile"),
    _case("_test_owner_mine_triggers_again_after_placement_turn"),
    _case("_test_passing_armed_mine_stops_and_triggers_followup"),
    _case("_test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending"),
  },
}
