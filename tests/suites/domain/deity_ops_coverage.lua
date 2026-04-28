local deity_ops = require("src.player.actions.state_ops.deity_ops")
local monopoly_event = require("src.core.events")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  local g = {
    dirty = { any = false, players = false },
  }
  function g:clear_player_deity(player) deity_ops.clear_player_deity(self, player) end
  return g
end

local function _make_player(opts)
  opts = opts or {}
  return {
    id = opts.id or "p1",
    status = opts.status or nil,
    deity_duration_turns = opts.deity_duration_turns or 3,
  }
end

-- player_has_deity

local function test_player_has_deity_false_when_no_status()
  local player = _make_player()
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "no status should return false")
end

local function test_player_has_deity_false_when_no_deity_in_status()
  local player = _make_player({ status = {} })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "no deity should return false")
end

local function test_player_has_deity_false_when_type_mismatch()
  local player = _make_player({ status = { deity = { type = "devil", remaining = 2 } } })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "wrong type should return false")
end

local function test_player_has_deity_false_when_remaining_zero()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 0 } } })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "remaining=0 should return false")
end

local function test_player_has_deity_true_when_matching()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), true, "matching deity with remaining>0 should return true")
end

-- player_has_angel

local function test_player_has_angel_delegates_to_player_has_deity()
  local game = _make_game()
  game.player_has_deity = deity_ops.player_has_deity
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.player_has_angel(game, player), true, "player_has_angel should return true for angel")
end

local function test_player_has_angel_false_for_other_deity()
  local game = _make_game()
  game.player_has_deity = deity_ops.player_has_deity
  local player = _make_player({ status = { deity = { type = "devil", remaining = 1 } } })
  _assert_eq(deity_ops.player_has_angel(game, player), false, "player_has_angel should return false for non-angel")
end

-- clear_player_deity

local function test_clear_player_deity_clears_type_and_remaining()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
  deity_ops.clear_player_deity(game, player)
  _assert_eq(player.status.deity.type, "", "deity type should be cleared")
  _assert_eq(player.status.deity.remaining, 0, "deity remaining should be 0")
  _assert_eq(game.dirty.players, true, "dirty.players should be set")
end

local function test_clear_player_deity_initializes_deity_if_nil()
  local game = _make_game()
  local player = _make_player({ status = {} })
  deity_ops.clear_player_deity(game, player)
  _assert_eq(player.status.deity.type, "", "deity type should be empty string")
  _assert_eq(player.status.deity.remaining, 0, "deity remaining should be 0")
end

-- set_player_deity

local function test_set_player_deity_sets_type_and_remaining()
  local game = _make_game()
  local player = _make_player()
  deity_ops.set_player_deity(game, player, "angel", 5)
  _assert_eq(player.status.deity.type, "angel", "deity type should be angel")
  _assert_eq(player.status.deity.remaining, 5, "deity remaining should be 5")
  _assert_eq(game.dirty.players, true, "dirty.players should be set")
end

local function test_set_player_deity_uses_player_duration_when_no_duration_arg()
  local game = _make_game()
  local player = _make_player({ deity_duration_turns = 4 })
  deity_ops.set_player_deity(game, player, "devil", nil)
  _assert_eq(player.status.deity.remaining, 4, "should use player.deity_duration_turns when no duration provided")
end

local function test_set_player_deity_emits_event()
  local game = _make_game()
  local player = _make_player()
  local emitted = nil
  local saved_emit = monopoly_event.emit
  monopoly_event.emit = function(event_name, payload) emitted = payload end
  deity_ops.set_player_deity(game, player, "angel", 3)
  monopoly_event.emit = saved_emit
  assert(emitted ~= nil, "should emit event")
  _assert_eq(emitted.deity_type, "angel", "emitted event should have deity_type")
  _assert_eq(emitted.remaining, 3, "emitted event should have remaining")
end

local function test_set_player_deity_errors_when_name_nil()
  local game = _make_game()
  local player = _make_player()
  local ok = pcall(function() deity_ops.set_player_deity(game, player, nil, 3) end)
  _assert_eq(ok, false, "nil name should error")
end

-- tick_player_deity

local function test_tick_player_deity_decrements_remaining()
  local game = _make_game()
  game.player_has_deity = deity_ops.player_has_deity
  local player = _make_player({ status = { deity = { type = "angel", remaining = 3 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 2, "tick should decrement remaining")
end

local function test_tick_player_deity_no_effect_when_remaining_zero()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 0 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 0, "no tick when remaining is 0")
  _assert_eq(game.dirty.players, false, "dirty.players should not be set when remaining=0")
end

local function test_tick_player_deity_clears_when_reaches_zero()
  local game = _make_game()
  game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 0, "deity should be cleared when reaching 0")
  _assert_eq(player.status.deity.type, "", "deity type should be cleared")
end

local function test_tick_player_deity_marks_dirty_when_remaining_stays_positive()
  local game = _make_game()
  game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
  local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(game.dirty.players, true, "dirty.players should be set when remaining > 0 after tick")
end

return {
  name = "domain deity ops coverage",
  tests = {
    { name = "player_has_deity false when no status", run = test_player_has_deity_false_when_no_status },
    { name = "player_has_deity false when no deity in status", run = test_player_has_deity_false_when_no_deity_in_status },
    { name = "player_has_deity false when type mismatch", run = test_player_has_deity_false_when_type_mismatch },
    { name = "player_has_deity false when remaining zero", run = test_player_has_deity_false_when_remaining_zero },
    { name = "player_has_deity true when matching", run = test_player_has_deity_true_when_matching },
    { name = "player_has_angel delegates to player_has_deity", run = test_player_has_angel_delegates_to_player_has_deity },
    { name = "player_has_angel false for other deity", run = test_player_has_angel_false_for_other_deity },
    { name = "clear_player_deity clears type and remaining", run = test_clear_player_deity_clears_type_and_remaining },
    { name = "clear_player_deity initializes deity if nil", run = test_clear_player_deity_initializes_deity_if_nil },
    { name = "set_player_deity sets type and remaining", run = test_set_player_deity_sets_type_and_remaining },
    { name = "set_player_deity uses player duration when no duration arg", run = test_set_player_deity_uses_player_duration_when_no_duration_arg },
    { name = "set_player_deity emits event", run = test_set_player_deity_emits_event },
    { name = "set_player_deity errors when name nil", run = test_set_player_deity_errors_when_name_nil },
    { name = "tick_player_deity decrements remaining", run = test_tick_player_deity_decrements_remaining },
    { name = "tick_player_deity no effect when remaining zero", run = test_tick_player_deity_no_effect_when_remaining_zero },
    { name = "tick_player_deity clears when reaches zero", run = test_tick_player_deity_clears_when_reaches_zero },
    { name = "tick_player_deity marks dirty when remaining stays positive", run = test_tick_player_deity_marks_dirty_when_remaining_stays_positive },
  },
}
