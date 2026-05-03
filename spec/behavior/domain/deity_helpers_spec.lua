---@diagnostic disable: undefined-field

local deity_ops = require("src.player.actions.state_ops.deity_ops")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_player(opts)
  opts = opts or {}
  return {
    id = opts.id or "p1",
    status = opts.status or nil,
    deity_duration_turns = opts.deity_duration_turns or 3,
  }
end

describe("domain deity helpers", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("player_has_any_deity false when no status", function()
    local player = _make_player()
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "no status should return false")
  end)

  it("player_has_any_deity false when no deity in status", function()
    local player = _make_player({ status = {} })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "no deity should return false")
  end)

  it("player_has_any_deity false for cleared placeholder", function()
    local player = _make_player({ status = { deity = { type = "", remaining = 0 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "cleared placeholder should return false")
  end)

  it("player_has_any_deity false for exhausted poor deity", function()
    local player = _make_player({ status = { deity = { type = "poor", remaining = 0 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "remaining=0 should return false")
  end)

  it("player_has_any_deity true for poor deity", function()
    local player = _make_player({ status = { deity = { type = "poor", remaining = 5 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "poor deity should return true")
  end)

  it("player_has_any_deity true for rich deity", function()
    local player = _make_player({ status = { deity = { type = "rich", remaining = 1 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "rich deity should return true")
  end)

  it("player_has_any_deity true for angel deity", function()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 3 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "angel deity should return true")
  end)

  it("game exposes player_has_any_deity mixin", function()
    local support = require("support.domain_support")
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    assert.is_function(game.player_has_any_deity)
  end)

  it("transfer_deity moves an effective deity from source to destination", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })
    local dst = _make_player({ id = "B" })

    assert.is_true(deity_ops.transfer_deity(game, src, dst))

    _assert_eq(src.status.deity.type, "", "src deity type should be cleared")
    _assert_eq(src.status.deity.remaining, 0, "src deity remaining should be zeroed")
    _assert_eq(dst.status.deity.type, "poor", "dst deity type should be transferred")
    _assert_eq(dst.status.deity.remaining, 5, "dst deity remaining should be transferred")
  end)

  it("transfer_deity rejects self-transfer", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local player = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })

    assert.has_error(function() deity_ops.transfer_deity(game, player, player) end, "cannot transfer to self")
  end)

  it("transfer_deity rejects an empty source deity", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "A", status = { deity = { type = "", remaining = 0 } } })
    local dst = _make_player({ id = "B" })

    assert.has_error(function() deity_ops.transfer_deity(game, src, dst) end, "src has no effective deity")
  end)

  it("transfer_deity overwrites an existing destination deity", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "B", status = { deity = { type = "poor", remaining = 5 } } })
    local dst = _make_player({ id = "A", status = { deity = { type = "rich", remaining = 3 } } })

    assert.is_true(deity_ops.transfer_deity(game, src, dst))

    _assert_eq(dst.status.deity.type, "poor", "dst deity should be overwritten")
    _assert_eq(dst.status.deity.remaining, 5, "dst remaining should be overwritten")
    _assert_eq(src.status.deity.type, "", "src deity type should be cleared")
    _assert_eq(src.status.deity.remaining, 0, "src deity remaining should be zeroed")
  end)

  it("transfer_deity raises guard flag only during transfer", function()
    local saw_guard = false
    local game = { dirty = {} }
    game.set_player_deity = function(self, player, name, duration)
      saw_guard = self._deity_transferring == true
      return deity_ops.set_player_deity(self, player, name, duration)
    end
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })
    local dst = _make_player({ id = "B" })

    assert.is_true(deity_ops.transfer_deity(game, src, dst))

    assert.is_true(saw_guard)
    _assert_eq(game._deity_transferring, false, "guard should be false after transfer")
  end)

  it("game exposes transfer_deity mixin", function()
    local support = require("support.domain_support")
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    assert.is_function(game.transfer_deity)
  end)

  it("set_player_deity rejects empty deity name", function()
    local game = { dirty = {} }
    local player = _make_player()

    assert.has_error(function() deity_ops.set_player_deity(game, player, "", 5) end, "deity name must be non-empty string")
  end)

  it("set_player_deity rejects nil deity name", function()
    local game = { dirty = {} }
    local player = _make_player()

    assert.has_error(function() deity_ops.set_player_deity(game, player, nil, 5) end, "deity name must be non-empty string")
  end)

  it("set_player_deity rejects zero duration", function()
    local game = { dirty = {} }
    local player = _make_player()

    assert.has_error(function() deity_ops.set_player_deity(game, player, "poor", 0) end, "explicit duration must be positive")
  end)

  it("set_player_deity rejects negative duration", function()
    local game = { dirty = {} }
    local player = _make_player()

    assert.has_error(function() deity_ops.set_player_deity(game, player, "poor", -1) end, "explicit duration must be positive")
  end)

  it("set_player_deity uses fallback duration when nil", function()
    local game = { dirty = {} }
    game.mark_players = function() end
    local player = _make_player({ deity_duration_turns = 7 })

    deity_ops.set_player_deity(game, player, "poor", nil)

    _assert_eq(player.status.deity.type, "poor", "deity type should be set")
    _assert_eq(player.status.deity.remaining, 7, "fallback duration should be used")
  end)

  it("set_player_deity accepts positive explicit duration", function()
    local game = { dirty = {} }
    game.mark_players = function() end
    local player = _make_player()

    deity_ops.set_player_deity(game, player, "poor", 5)

    _assert_eq(player.status.deity.type, "poor", "deity type should be set")
    _assert_eq(player.status.deity.remaining, 5, "explicit duration should be used")
  end)

  it("tick_player_deity leaves eliminated player remaining unchanged", function()
    local game = { dirty = {} }
    game.clear_player_deity = deity_ops.clear_player_deity
    game.mark_players = function() error("should not mark eliminated player") end
    local player = _make_player({ status = { deity = { type = "poor", remaining = 4 } } })
    player.eliminated = true

    deity_ops.tick_player_deity(game, player)

    _assert_eq(player.status.deity.remaining, 4, "eliminated player should not tick down")
  end)

  it("tick_player_deity decrements non-eliminated player remaining", function()
    local game = { dirty = {} }
    game.clear_player_deity = deity_ops.clear_player_deity
    game.mark_players = function() end
    local player = _make_player({ status = { deity = { type = "poor", remaining = 4 } } })

    deity_ops.tick_player_deity(game, player)

    _assert_eq(player.status.deity.remaining, 3, "non-eliminated player should tick down")
  end)

  it("tick_player_deity ignores eliminated player with residual deity", function()
    local game = { dirty = {} }
    game.clear_player_deity = deity_ops.clear_player_deity
    game.mark_players = function() error("should not mark eliminated player") end
    local player = _make_player({ status = { deity = { type = "poor", remaining = 1 } } })
    player.eliminated = true

    assert.has_no_errors(function() deity_ops.tick_player_deity(game, player) end)
    _assert_eq(player.status.deity.type, "poor", "residual deity should stay intact")
    _assert_eq(player.status.deity.remaining, 1, "residual deity should remain unchanged")
  end)

end)
