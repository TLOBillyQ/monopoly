local gameplay_cases = require("suites.gameplay.shared.cases")

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
  name = "gameplay_bankruptcy_and_tile_owner",
  tests = {
    _case("_test_mandatory_payment_causes_bankruptcy"),
    _case("_test_bankruptcy_resets_owned_tiles"),
    _case("_test_bankruptcy_notifier_reads_grouped_ports"),
    _case("_test_game_victory_finished_game_short_circuits_without_reemitting"),
    _case("_test_game_victory_turn_limit_tie_keeps_multiple_winners"),
    _case("_test_game_victory_turn_limit_with_no_survivors_reports_empty_winners"),
    _case("_test_chance_pay_others_stops_after_bankruptcy"),
    _case("_test_set_tile_owner_without_ui_port_does_not_crash"),
    _case("_test_tile_owner_notifier_receives_owner_changes"),
  },
}
