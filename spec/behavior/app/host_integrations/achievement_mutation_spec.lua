-- Mutation-pinning specs for src/app/host_integrations/achievement.lua.
-- Catalog ids are 1..45 contiguous; progress events include "游戏胜利" -> {1,2,3,4}.

local achievement = require("src.app.host_integrations.achievement")

describe("achievement.mapped_ids_for_event L15/L129/L132 survivors", function()
  after_each(function()
    achievement.reset_for_tests()
  end)

  it("returns a copy of the mapped ids for a known event (L15 ipairs->nil, L132 ->nil)", function()
    local ids = achievement.mapped_ids_for_event("游戏胜利")
    -- L132 `_copy_ids(mapped.ids)` -> nil would return nil.
    assert(type(ids) == "table", "mapped ids must be a table; got " .. type(ids))
    -- L15 `ipairs(ids or {})` -> nil crashes the copy loop, failing (killing) the test.
    assert(#ids == 4, "游戏胜利 must map to 4 ids; got " .. tostring(#ids))
    assert(ids[1] == 1 and ids[2] == 2 and ids[3] == 3 and ids[4] == 4,
      "mapped ids must be {1,2,3,4}; got " .. tostring(ids[1]) .. "," .. tostring(ids[2])
      .. "," .. tostring(ids[3]) .. "," .. tostring(ids[4]))
  end)

  it("returns an empty table for an unknown event (L129 ==->~=)", function()
    -- L129 `mapped == nil` -> `mapped ~= nil`: for a missing event the mutant
    -- skips the empty-return and indexes nil.ids, crashing (killing) the test.
    local ids = achievement.mapped_ids_for_event("no_such_event_zzz")
    assert(type(ids) == "table", "unknown event must return a table; got " .. type(ids))
    assert(#ids == 0, "unknown event must return an empty table; got #" .. tostring(#ids))
  end)
end)

describe("achievement.ids_are_contiguous L69 _has_every_id survivor", function()
  it("returns false when the range count matches but an id is missing (L69 false->true)", function()
    -- Catalog holds 45 ids (1..45). Range [2,46] has count 45 == #catalog, so the
    -- count guard passes and _has_every_id runs: find(46) is nil.
    -- L69 `return false` -> `true` would make the missing id look present.
    assert(achievement.ids_are_contiguous(2, 46) == false,
      "range [2,46] contains missing id 46 and must not be contiguous")
  end)

  it("returns true for the real contiguous range [1,45] (sanity)", function()
    assert(achievement.ids_are_contiguous(1, 45) == true,
      "the full catalog range must be contiguous")
  end)
end)

describe("achievement.set_progress L152 survivor", function()
  after_each(function()
    achievement.reset_for_tests()
  end)

  it("returns the _apply_progress boolean result (L152 ->nil)", function()
    local captured = {}
    local adapter = {
      set_achievement_progress = function(id, count)
        captured.id = id
        captured.count = count
        return true
      end,
    }
    -- id 1 is valid, count 5 is integer -> _apply_progress reaches _call_host,
    -- adapter succeeds -> result true. L152 `_apply_progress(...)` -> nil returns nil.
    local result = achievement.set_progress(1, 5, adapter)
    assert(result == true, "set_progress must return true on success; got " .. tostring(result))
    assert(captured.id == 1 and captured.count == 5,
      "adapter must receive normalized (id, count); got "
      .. tostring(captured.id) .. "," .. tostring(captured.count))
  end)
end)
