local registry = require("gameplay_registry")
local gameplay = require("gameplay")

local suite = registry.slice("gameplay.loop", 17, 41)
local retry_test = gameplay[#gameplay]
assert(type(retry_test) == "function", "missing gameplay retry test at tail index")
suite.tests[#suite.tests + 1] = {
  name = "_test_game_startup_role_roster_retries_before_debug_players_fallback",
  run = retry_test,
}

return suite
