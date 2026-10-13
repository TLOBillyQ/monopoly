require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- dirty_tracker 直测:mark 域校验、mark_turn nil guard、mark_inventory 布尔域、
-- merge/reset/consume 标量语义。

local dirty_tracker = require("src.state.dirty_tracker")

describe("TestDirtyTracker", function()

  it("test_mark_raises_on_unknown_domain", function()
    local d = dirty_tracker.new()
    luassert.has_error(function()
      dirty_tracker.mark(d, "nonsense")
    end, "unknown dirty domain: nonsense")
  end)

  it("test_mark_sets_any_and_domain", function()
    local d = dirty_tracker.new()
    dirty_tracker.mark(d, "players")
    luassert.truthy(d.any == true, "any must be true")
    luassert.truthy(d.players == true, "domain must be true")
  end)

  it("test_mark_turn_nil_game_returns_nil", function()
    local result = dirty_tracker.mark_turn(nil)
    luassert.truthy(result == nil, "nil game must return nil")
  end)

  it("test_mark_turn_without_dirty_is_safe", function()
    local result = dirty_tracker.mark_turn({})
    luassert.truthy(result == nil, "game without dirty must return nil")
  end)

  it("test_mark_inventory_sets_boolean_flags", function()
    local d = dirty_tracker.new()
    dirty_tracker.mark_inventory(d)
    luassert.truthy(d.any == true, "any must be true")
    luassert.truthy(d.players == true, "players must be true")
    luassert.truthy(d.inventory == true, "inventory flag must be true")
  end)

  it("test_merge_into_with_non_table_returns_target", function()
    local target = { x = 1 }
    local result = dirty_tracker.merge_into(target, "junk")
    luassert.truthy(result == target, "non-table dirty must return target unchanged")
    luassert.truthy(target.x == 1, "target must be untouched")
  end)

  it("test_merge_into_copies_dirty_flags", function()
    local target = dirty_tracker.new()
    local dirty = dirty_tracker.new()
    dirty_tracker.mark(dirty, "players")
    dirty_tracker.mark_inventory(dirty)
    dirty_tracker.merge_into(target, dirty)
    luassert.truthy(target.players == true, "players flag must merge")
    luassert.truthy(target.inventory == true, "inventory flag must merge")
  end)

  it("test_reset_clears_all_keys", function()
    local d = dirty_tracker.new()
    dirty_tracker.mark(d, "players")
    dirty_tracker.mark_inventory(d)
    dirty_tracker.reset(d)
    luassert.truthy(d.any == false, "any must be false after reset")
    luassert.truthy(d.players == false, "players must be false after reset")
    luassert.truthy(d.inventory == false, "inventory must be false after reset")
  end)

  it("test_consume_captures_flags_and_resets_source", function()
    local d = dirty_tracker.new()
    dirty_tracker.mark(d, "players")
    dirty_tracker.mark_inventory(d)
    local snap = dirty_tracker.consume(d)
    luassert.truthy(snap.players == true, "snap must capture players flag")
    luassert.truthy(snap.inventory == true, "snap must capture inventory flag")
    luassert.truthy(d.players == false, "d must be reset after consume")
    luassert.truthy(d.inventory == false, "d inventory must be reset after consume")
  end)

  it("test_consume_clears_snapshot_between_calls", function()
    local d = dirty_tracker.new()
    dirty_tracker.mark_inventory(d)
    dirty_tracker.consume(d)

    dirty_tracker.mark(d, "players")
    local snap = dirty_tracker.consume(d)
    luassert.truthy(snap.players == true, "snap must capture players flag")
    luassert.truthy(snap.inventory == false, "snap must not carry inventory from first call")
  end)

end)
