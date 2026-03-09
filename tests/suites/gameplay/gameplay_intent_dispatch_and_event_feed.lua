local gameplay_cases = require("suites.gameplay.gameplay_cases")

local function _case(name)
  return {
    name = name,
    run = assert(gameplay_cases[name], "missing gameplay case: " .. tostring(name)),
  }
end

return {
  name = "gameplay_intent_dispatch_and_event_feed",
  tests = {
    _case("_test_dispatch_validator_accepts_ui_state_snapshot"),
    _case("_test_intent_dispatcher_sets_choice_route_metadata"),
    _case("_test_intent_dispatcher_sets_choice_route_metadata"),
  },
}
