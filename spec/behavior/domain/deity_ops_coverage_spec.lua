local deity_ops = require("src.player.actions.state_ops.deity")
local monopoly_event = require("src.foundation.events")

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






-- player_has_angel



-- clear_player_deity



-- set_player_deity





-- tick_player_deity

describe("domain deity ops coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("player_has_deity false when no status", function()
    local player = _make_player()
    _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "no status should return false")
  end)

  it("player_has_deity false when no deity in status", function()
    local player = _make_player({ status = {} })
    _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "no deity should return false")
  end)

  it("player_has_deity false when type mismatch", function()
    local player = _make_player({ status = { deity = { type = "devil", remaining = 2 } } })
    _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "wrong type should return false")
  end)

  it("player_has_deity false when remaining zero", function()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 0 } } })
    _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "remaining=0 should return false")
  end)

  it("player_has_deity true when matching", function()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
    _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), true, "matching deity with remaining>0 should return true")
  end)

  it("player_has_angel delegates to player_has_deity", function()
    local game = _make_game()
    game.player_has_deity = deity_ops.player_has_deity
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.player_has_angel(game, player), true, "player_has_angel should return true for angel")
  end)

  it("player_has_angel false for other deity", function()
    local game = _make_game()
    game.player_has_deity = deity_ops.player_has_deity
    local player = _make_player({ status = { deity = { type = "devil", remaining = 1 } } })
    _assert_eq(deity_ops.player_has_angel(game, player), false, "player_has_angel should return false for non-angel")
  end)

  it("clear_player_deity clears type and remaining", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
    deity_ops.clear_player_deity(game, player)
    _assert_eq(player.status.deity.type, "", "deity type should be cleared")
    _assert_eq(player.status.deity.remaining, 0, "deity remaining should be 0")
    _assert_eq(game.dirty.players, true, "dirty.players should be set")
  end)

  it("clear_player_deity initializes deity if nil", function()
    local game = _make_game()
    local player = _make_player({ status = {} })
    deity_ops.clear_player_deity(game, player)
    _assert_eq(player.status.deity.type, "", "deity type should be empty string")
    _assert_eq(player.status.deity.remaining, 0, "deity remaining should be 0")
  end)

  it("set_player_deity sets type and remaining", function()
    local game = _make_game()
    local player = _make_player()
    deity_ops.set_player_deity(game, player, "angel", 5)
    _assert_eq(player.status.deity.type, "angel", "deity type should be angel")
    _assert_eq(player.status.deity.remaining, 6, "internal remaining is duration+1")
    _assert_eq(game.dirty.players, true, "dirty.players should be set")
  end)

  it("set_player_deity uses player duration when no duration arg", function()
    local game = _make_game()
    local player = _make_player({ deity_duration_turns = 4 })
    deity_ops.set_player_deity(game, player, "devil", nil)
    _assert_eq(player.status.deity.remaining, 5, "internal remaining is deity_duration_turns+1")
  end)

  it("set_player_deity emits event", function()
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
  end)

  it("set_player_deity errors when name nil", function()
    local game = _make_game()
    local player = _make_player()
    local ok = pcall(function() deity_ops.set_player_deity(game, player, nil, 3) end)
    _assert_eq(ok, false, "nil name should error")
  end)

  it("tick_player_deity decrements remaining", function()
    local game = _make_game()
    game.player_has_deity = deity_ops.player_has_deity
    local player = _make_player({ status = { deity = { type = "angel", remaining = 3 } } })
    deity_ops.tick_player_deity(game, player)
    _assert_eq(player.status.deity.remaining, 2, "tick should decrement remaining")
  end)

  it("tick_player_deity no effect when remaining zero", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 0 } } })
    deity_ops.tick_player_deity(game, player)
    _assert_eq(player.status.deity.remaining, 0, "no tick when remaining is 0")
    _assert_eq(game.dirty.players, false, "dirty.players should not be set when remaining=0")
  end)

  it("tick_player_deity clears when reaches zero", function()
    local game = _make_game()
    game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    deity_ops.tick_player_deity(game, player)
    _assert_eq(player.status.deity.remaining, 0, "deity should be cleared when reaching 0")
    _assert_eq(player.status.deity.type, "", "deity type should be cleared")
  end)

  it("tick_player_deity marks dirty when remaining stays positive", function()
    local game = _make_game()
    game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
    local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
    deity_ops.tick_player_deity(game, player)
    _assert_eq(game.dirty.players, true, "dirty.players should be set when remaining > 0 after tick")
  end)

  it("activation-turn tick brings remaining to nominal duration", function()
    local game = _make_game()
    game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
    local player = _make_player({ deity_duration_turns = 10 })
    deity_ops.set_player_deity(game, player, "rich", nil)
    deity_ops.tick_player_deity(game, player)
    _assert_eq(player.status.deity.remaining, 10, "after activation-turn tick, remaining should equal duration")
    _assert_eq(player.status.deity.type, "rich", "deity type should persist")
  end)

  it("deity lasts exactly N effective turns after activation", function()
    local game = _make_game()
    game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
    local duration = 5
    local player = _make_player({ deity_duration_turns = duration })
    deity_ops.set_player_deity(game, player, "angel", duration)
    for _ = 1, duration do
      deity_ops.tick_player_deity(game, player)
    end
    _assert_eq(player.status.deity.remaining, 1, "after N ticks (incl activation), remaining=1")
    deity_ops.tick_player_deity(game, player)
    _assert_eq(player.status.deity.type, "", "deity cleared after N+1 total ticks")
  end)
end)
