local registry = require("suites.presentation.registry")
local all = require("presentation.presentation_ui")

local suite = registry.slice("presentation_ui.interaction", 28, 36)

suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_injects_actor_for_next_with_current_player_fallback",
  run = assert(all[108], "missing presentation_ui test at index 108"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_injects_actor_for_market_confirm_and_cancel",
  run = assert(all[109], "missing presentation_ui test at index 109"),
}
suite.tests[#suite.tests + 1] = {
  name = "_test_ui_event_router_rejects_next_without_actor_context",
  run = assert(all[110], "missing presentation_ui test at index 110"),
}

return suite
