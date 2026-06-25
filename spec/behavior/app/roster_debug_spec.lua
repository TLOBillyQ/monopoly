local roster_debug = require("src.app.roster_debug")
local debug_flags = require("src.config.gameplay.debug_flags")

local function _count(map)
  local n = 0
  for _ in pairs(map or {}) do
    n = n + 1
  end
  return n
end

describe("roster_debug.build_auto_players", function()
  after_each(function()
    debug_flags.reset()
  end)

  it("returns nil for release builds even when the debug flag is on", function()
    debug_flags.debug_auto_non_primary = true
    local result = roster_debug.build_auto_players(
      { { role_id = 1 }, { role_id = 2 }, { role_id = 3 } },
      "release"
    )
    assert(result == nil, "release builds must never auto-drive non-primary seats")
  end)

  it("returns nil when debug_auto_non_primary is disabled", function()
    debug_flags.debug_auto_non_primary = false
    local result = roster_debug.build_auto_players(
      { { role_id = 1 }, { role_id = 2 } },
      "debug"
    )
    assert(result == nil, "disabled debug flag must not produce an auto map")
  end)

  it("marks every non-primary seat for a non-release build with the flag on", function()
    debug_flags.debug_auto_non_primary = true
    local result = roster_debug.build_auto_players(
      { { role_id = 11 }, { role_id = 22 }, { role_id = 33 } },
      "debug"
    )
    assert(result ~= nil, "debug build with the flag on should produce an auto map")
    assert(result[22] == true, "second seat should be auto-driven")
    assert(result[33] == true, "third seat should be auto-driven")
    assert(result[11] == nil, "the primary (first) seat must never be auto-driven")
    assert(_count(result) == 2, "exactly the two non-primary seats should be marked")
  end)

  it("skips entries without a role_id but keeps later valid seats", function()
    debug_flags.debug_auto_non_primary = true
    local result = roster_debug.build_auto_players(
      { { role_id = 1 }, { role_id = nil }, { role_id = 7 } },
      "debug"
    )
    assert(result ~= nil, "a valid non-primary seat should still produce a map")
    assert(result[7] == true, "the valid later seat should be auto-driven")
    assert(_count(result) == 1, "the role_id-less seat should contribute no entry")
  end)

  it("allocates no map when only a primary seat is present", function()
    debug_flags.debug_auto_non_primary = true
    local result = roster_debug.build_auto_players({ { role_id = 1 } }, "debug")
    assert(result == nil, "with no non-primary seats no auto map is allocated")
  end)
end)
