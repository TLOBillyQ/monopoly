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
  },
}
