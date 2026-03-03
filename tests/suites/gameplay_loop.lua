local registry = require("gameplay_registry")
local gameplay = require("gameplay")

local suite = registry.slice("gameplay.loop", 17, 41)
local retry_test = gameplay[44]
assert(type(retry_test) == "function", "missing gameplay test at index 44")
suite.tests[#suite.tests + 1] = {
  name = "_test_game_startup_role_roster_retries_before_debug_players_fallback",
  run = retry_test,
}

return suite
