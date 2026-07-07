-- Mutation-pinning specs for src/foundation/log.lua.
-- _list_entries / _take_entries are local, but logger.formatter exposes
-- get_entries(state, max_lines) = _take_entries(_list_entries(state), max_lines),
-- letting us drive them with a crafted state.

local logger = require("src.foundation.log")

describe("log.lua mutation pins", function()
  it("L107 _list_entries returns {} when #entries==0 even with a hidden slot (kills 'or'->'and')", function()
    -- entries has a real value at index 2 but a __len metamethod forcing #==0.
    -- Original guard `count<=0 or #entries==0`: #entries==0 true -> return {}.
    -- Mutant `count<=0 and #entries==0`: 1<=0 false -> whole guard false ->
    --   proceeds into the ring loop, reads entries[2], and returns a 1-elem list.
    local ghost = { level = "info", text = "ghost", time_text = "" }
    local entries = setmetatable({ [2] = ghost }, { __len = function() return 0 end })
    local state = {
      entries = entries,
      entries_count = 1, -- count > 0 so the count<=0 clause is false
      entries_head = 2,  -- slot ((2 + 1 - 2) % 2) + 1 == 2 -> reads entries[2]
      max_entries = 2,   -- capacity comes from here, not from #entries
    }
    local out = logger.formatter.get_entries(state, nil)
    assert(type(out) == "table", "get_entries must return a table")
    assert(#out == 0,
      "empty #entries must yield no listed entries; 'and' mutant leaks the hidden slot. got #out=" .. #out)
  end)
end)
