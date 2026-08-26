-- dirty_tracker 直测:mark 域校验、mark_turn nil guard、mark_inventory 布尔域、
-- merge/reset/consume 标量语义。
local lu = require("luaunit")
local luax = require("test.support.luax")

local dirty_tracker = require("src.state.dirty_tracker")

TestDirtyTracker = {}

function TestDirtyTracker:test_mark_raises_on_unknown_domain()
  local d = dirty_tracker.new()
  luax.has_error(function()
    dirty_tracker.mark(d, "nonsense")
  end, "unknown dirty domain: nonsense")
end

function TestDirtyTracker:test_mark_sets_any_and_domain()
  local d = dirty_tracker.new()
  dirty_tracker.mark(d, "players")
  lu.assertEvalToTrue(d.any == true, "any must be true")
  lu.assertEvalToTrue(d.players == true, "domain must be true")
end

function TestDirtyTracker:test_mark_turn_nil_game_returns_nil()
  local result = dirty_tracker.mark_turn(nil)
  lu.assertEvalToTrue(result == nil, "nil game must return nil")
end

function TestDirtyTracker:test_mark_turn_without_dirty_is_safe()
  local result = dirty_tracker.mark_turn({})
  lu.assertEvalToTrue(result == nil, "game without dirty must return nil")
end

function TestDirtyTracker:test_mark_inventory_sets_boolean_flags()
  local d = dirty_tracker.new()
  dirty_tracker.mark_inventory(d)
  lu.assertEvalToTrue(d.any == true, "any must be true")
  lu.assertEvalToTrue(d.players == true, "players must be true")
  lu.assertEvalToTrue(d.inventory == true, "inventory flag must be true")
end

function TestDirtyTracker:test_merge_into_with_non_table_returns_target()
  local target = { x = 1 }
  local result = dirty_tracker.merge_into(target, "junk")
  lu.assertEvalToTrue(result == target, "non-table dirty must return target unchanged")
  lu.assertEvalToTrue(target.x == 1, "target must be untouched")
end

function TestDirtyTracker:test_merge_into_copies_dirty_flags()
  local target = dirty_tracker.new()
  local dirty = dirty_tracker.new()
  dirty_tracker.mark(dirty, "players")
  dirty_tracker.mark_inventory(dirty)
  dirty_tracker.merge_into(target, dirty)
  lu.assertEvalToTrue(target.players == true, "players flag must merge")
  lu.assertEvalToTrue(target.inventory == true, "inventory flag must merge")
end

function TestDirtyTracker:test_reset_clears_all_keys()
  local d = dirty_tracker.new()
  dirty_tracker.mark(d, "players")
  dirty_tracker.mark_inventory(d)
  dirty_tracker.reset(d)
  lu.assertEvalToTrue(d.any == false, "any must be false after reset")
  lu.assertEvalToTrue(d.players == false, "players must be false after reset")
  lu.assertEvalToTrue(d.inventory == false, "inventory must be false after reset")
end

function TestDirtyTracker:test_consume_captures_flags_and_resets_source()
  local d = dirty_tracker.new()
  dirty_tracker.mark(d, "players")
  dirty_tracker.mark_inventory(d)
  local snap = dirty_tracker.consume(d)
  lu.assertEvalToTrue(snap.players == true, "snap must capture players flag")
  lu.assertEvalToTrue(snap.inventory == true, "snap must capture inventory flag")
  lu.assertEvalToTrue(d.players == false, "d must be reset after consume")
  lu.assertEvalToTrue(d.inventory == false, "d inventory must be reset after consume")
end

function TestDirtyTracker:test_consume_clears_snapshot_between_calls()
  local d = dirty_tracker.new()
  dirty_tracker.mark_inventory(d)
  dirty_tracker.consume(d)

  dirty_tracker.mark(d, "players")
  local snap = dirty_tracker.consume(d)
  lu.assertEvalToTrue(snap.players == true, "snap must capture players flag")
  lu.assertEvalToTrue(snap.inventory == false,
    "snap must not carry inventory from first call")
end

return TestDirtyTracker
