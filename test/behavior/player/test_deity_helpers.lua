require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
---@diagnostic disable: undefined-field

local deity_ops = require("src.player.actions.deity")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  luassert.truthy(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_player(opts)
  opts = opts or {}
  return {
    id = opts.id or "p1",
    status = opts.status or nil,
    deity_duration_turns = opts.deity_duration_turns or 3,
  }
end

describe("TestDeityHelpers", function()

  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_player_has_any_deity_false_when_no_status", function()
    local player = _make_player()
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "no status should return false")
  end)

  it("test_player_has_any_deity_false_when_no_deity_in_status", function()
    local player = _make_player({ status = {} })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "no deity should return false")
  end)

  it("test_player_has_any_deity_false_for_cleared_placeholder", function()
    local player = _make_player({ status = { deity = { type = "", remaining = 0 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "cleared placeholder should return false")
  end)

  it("test_player_has_any_deity_false_for_exhausted_poor_deity", function()
    local player = _make_player({ status = { deity = { type = "poor", remaining = 0 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "remaining=0 should return false")
  end)

  it("test_player_has_any_deity_true_for_poor_deity", function()
    local player = _make_player({ status = { deity = { type = "poor", remaining = 5 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "poor deity should return true")
  end)

  it("test_player_has_any_deity_true_for_rich_deity", function()
    local player = _make_player({ status = { deity = { type = "rich", remaining = 1 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "rich deity should return true")
  end)

  it("test_player_has_any_deity_true_for_angel_deity", function()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 3 } } })
    _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "angel deity should return true")
  end)

  it("test_game_exposes_player_has_any_deity_mixin", function()
    local support = require("test.support.shared_support")
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    luassert.is_function(game.player_has_any_deity)
  end)

  it("test_transfer_deity_moves_effective_deity_from_source_to_destination", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })
    local dst = _make_player({ id = "B" })

    luassert.is_true(deity_ops.transfer_deity(game, src, dst))

    _assert_eq(src.status.deity.type, "", "src deity type should be cleared")
    _assert_eq(src.status.deity.remaining, 0, "src deity remaining should be zeroed")
    _assert_eq(dst.status.deity.type, "poor", "dst deity type should be transferred")
    _assert_eq(dst.status.deity.remaining, 4, "dst deity remaining resets to full duration+1 (#529)")
  end)

  it("test_transfer_deity_rejects_self_transfer", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local player = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })

    luassert.has_error(function() deity_ops.transfer_deity(game, player, player) end, "cannot transfer to self")
  end)

  it("test_transfer_deity_rejects_empty_source_deity", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "A", status = { deity = { type = "", remaining = 0 } } })
    local dst = _make_player({ id = "B" })

    luassert.has_error(function() deity_ops.transfer_deity(game, src, dst) end, "src has no effective deity")
  end)

  it("test_transfer_deity_overwrites_existing_destination_deity", function()
    local game = { dirty = {} }
    game.set_player_deity = deity_ops.set_player_deity
    game.clear_player_deity = deity_ops.clear_player_deity
    local src = _make_player({ id = "B", status = { deity = { type = "poor", remaining = 5 } } })
    local dst = _make_player({ id = "A", status = { deity = { type = "rich", remaining = 3 } } })

    luassert.is_true(deity_ops.transfer_deity(game, src, dst))

    _assert_eq(dst.status.deity.type, "poor", "dst deity should be overwritten")
    _assert_eq(dst.status.deity.remaining, 4, "dst remaining resets to full duration+1 (#529)")
    _assert_eq(src.status.deity.type, "", "src deity type should be cleared")
    _assert_eq(src.status.deity.remaining, 0, "src deity remaining should be zeroed")
  end)

  it("test_transfer_deity_raises_guard_flag_only_during_transfer", function()
    local saw_guard = false
    local game = { dirty = {} }
    game.clear_player_deity = function(self, player)
      saw_guard = self._deity_transferring == true
      return deity_ops.clear_player_deity(self, player)
    end
    local src = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })
    local dst = _make_player({ id = "B" })

    luassert.is_true(deity_ops.transfer_deity(game, src, dst))

    luassert.is_true(saw_guard)
    _assert_eq(game._deity_transferring, false, "guard should be false after transfer")
  end)

  it("test_game_exposes_transfer_deity_mixin", function()
    local support = require("test.support.shared_support")
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    luassert.is_function(game.transfer_deity)
  end)

  it("test_set_player_deity_rejects_empty_deity_name", function()
    local game = { dirty = {} }
    local player = _make_player()

    luassert.has_error(function() deity_ops.set_player_deity(game, player, "", 5) end, "deity name must be non-empty string")
  end)

  it("test_set_player_deity_rejects_zero_duration", function()
    local game = { dirty = {} }
    local player = _make_player()

    luassert.has_error(function() deity_ops.set_player_deity(game, player, "poor", 0) end, "explicit duration must be positive")
  end)

  it("test_set_player_deity_rejects_negative_duration", function()
    local game = { dirty = {} }
    local player = _make_player()

    luassert.has_error(function() deity_ops.set_player_deity(game, player, "poor", -1) end, "explicit duration must be positive")
  end)

  it("test_tick_player_deity_leaves_eliminated_remaining_unchanged", function()
    local game = { dirty = {} }
    game.clear_player_deity = deity_ops.clear_player_deity
    game.mark_players = function() error("should not mark eliminated player") end
    local player = _make_player({ status = { deity = { type = "poor", remaining = 4 } } })
    player.eliminated = true

    deity_ops.tick_player_deity(game, player)

    _assert_eq(player.status.deity.remaining, 4, "eliminated player should not tick down")
  end)

  it("test_tick_player_deity_ignores_eliminated_player_with_residual_deity", function()
    local game = { dirty = {} }
    game.clear_player_deity = deity_ops.clear_player_deity
    game.mark_players = function() error("should not mark eliminated player") end
    local player = _make_player({ status = { deity = { type = "poor", remaining = 1 } } })
    player.eliminated = true

    luassert.has_no.errors(function() deity_ops.tick_player_deity(game, player) end)
    _assert_eq(player.status.deity.type, "poor", "residual deity should stay intact")
    _assert_eq(player.status.deity.remaining, 1, "residual deity should remain unchanged")
  end)


end)
