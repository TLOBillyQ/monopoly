local suite_builder = require("suites.gameplay.suite_builder")

return suite_builder.build_suite("gameplay_turn_flow_and_interrupts", {
  "_test_complex_consecutive_turn_settlement",
  "_test_complex_market_interrupt_with_rent",
})
