local registry = require("presentation_ui_registry")
local all = require("presentation_ui")

local suite = registry.slice("presentation_ui.interaction", 28, 37)

suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_injects_actor_for_next_with_current_player_fallback",
  run = assert(all[92], "missing presentation_ui test at index 92"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_injects_actor_for_market_confirm_and_cancel",
  run = assert(all[93], "missing presentation_ui test at index 93"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_rejects_next_without_actor_context",
  run = assert(all[94], "missing presentation_ui test at index 94"),
}

return suite
