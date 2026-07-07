-- Semantic seam over player.status storage (arch: turn/rules must not read/write
-- player.status.<field> directly). Detention follows ADR 0024 含当前回合口径:
-- the player-visible remaining includes the current frozen turn, stays >= 1 while
-- detained, and the stay ends when the internal counter reaches 0.
local status_ops = require("src.player.actions.status")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  return { dirty = { any = false, players = false } }
end

local function _make_player(status)
  return { id = "p1", name = "P1", status = status }
end

describe("player status semantic seam", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  describe("pending_dice_multiplier", function()
    it("peek normalizes unset/nil status to 1", function()
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player(nil)), 1, "nil status")
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({})), 1, "empty status")
    end)

    it("peek normalizes <=1 values to 1", function()
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({ pending_dice_multiplier = 1 })), 1, "1")
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({ pending_dice_multiplier = 0 })), 1, "0")
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({ pending_dice_multiplier = 0.5 })), 1,
        "any value <= 1 is no multiplier")
    end)

    it("peek returns the pending multiplier when > 1 without clearing it", function()
      local player = _make_player({ pending_dice_multiplier = 4 })
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, player), 4, "peek")
      _assert_eq(status_ops.player_pending_dice_multiplier(nil, player), 4, "peek must not consume")
    end)

    it("consume returns the multiplier and resets it to 1", function()
      local game = _make_game()
      local player = _make_player({ pending_dice_multiplier = 3 })
      _assert_eq(status_ops.consume_pending_dice_multiplier(game, player), 3, "consume returns value")
      _assert_eq(status_ops.player_pending_dice_multiplier(game, player), 1, "consumed multiplier reads 1")
      -- owning-layer layout pin: consume must store the canonical 1 (same value
      -- clear_player_temporal_flags writes), not merely a value that normalizes to 1.
      _assert_eq(player.status.pending_dice_multiplier, 1, "consume stores canonical 1")
      _assert_eq(game.dirty.players, true, "consume marks players dirty")
    end)
  end)

  describe("pending_remote_dice", function()
    it("peek returns nil when nothing pending", function()
      _assert_eq(status_ops.peek_pending_remote_dice(nil, _make_player(nil)), nil, "nil status")
      _assert_eq(status_ops.peek_pending_remote_dice(nil, _make_player({})), nil, "empty status")
    end)

    it("set then peek round-trips the values without consuming", function()
      local game = _make_game()
      local player = _make_player({})
      status_ops.set_pending_remote_dice(game, player, { 4, 4 })
      local values = status_ops.peek_pending_remote_dice(game, player)
      _assert_eq(values ~= nil and values[1], 4, "first value")
      _assert_eq(values ~= nil and values[2], 4, "second value")
      _assert_eq(status_ops.peek_pending_remote_dice(game, player) ~= nil, true, "peek must not consume")
      _assert_eq(game.dirty.players, true, "set marks players dirty")
    end)

    it("set rejects empty values", function()
      local ok = pcall(status_ops.set_pending_remote_dice, _make_game(), _make_player({}), {})
      _assert_eq(ok, false, "empty values must be rejected")
    end)
  end)

  describe("detention (ADR 0024 含当前回合)", function()
    it("remaining is 0 when never detained or counter is non-positive", function()
      _assert_eq(status_ops.detention_remaining(nil, _make_player(nil)), 0, "nil status")
      _assert_eq(status_ops.detention_remaining(nil, _make_player({ stay_turns = 0 })), 0, "zero")
      _assert_eq(status_ops.detention_remaining(nil, _make_player({ stay_turns = -1 })), 0, "negative clamps to 0")
    end)

    it("remaining stays >= 1 across a 2-turn stay and only hits 0 on release", function()
      local game = _make_game()
      local player = _make_player({ stay_turns = 2 })
      _assert_eq(status_ops.detention_remaining(game, player), 2, "before first frozen turn")
      _assert_eq(status_ops.consume_detention_turn(game, player), 2, "first frozen turn shows inclusive 2")
      _assert_eq(status_ops.detention_remaining(game, player), 1, "still detained after first turn")
      _assert_eq(status_ops.consume_detention_turn(game, player), 1, "last frozen turn shows inclusive 1, never 0")
      _assert_eq(status_ops.detention_remaining(game, player), 0, "released once counter reaches 0")
    end)

    it("consume on a free player returns 0 and does not go negative", function()
      local game = _make_game()
      local player = _make_player({ stay_turns = 0 })
      _assert_eq(status_ops.consume_detention_turn(game, player), 0, "free player consumes nothing")
      _assert_eq(status_ops.detention_remaining(game, player), 0, "remaining stays 0")
      _assert_eq(game.dirty.players, false, "no-op consume must not mark dirty")
    end)

    it("consume marks players dirty when a detention turn is spent", function()
      local game = _make_game()
      local player = _make_player({ stay_turns = 1 })
      status_ops.consume_detention_turn(game, player)
      _assert_eq(game.dirty.players, true, "consume marks players dirty")
    end)
  end)

  describe("own_turn_started_count", function()
    it("reads 0 when unset", function()
      _assert_eq(status_ops.player_own_turn_started_count(nil, _make_player(nil)), 0, "nil status")
      _assert_eq(status_ops.player_own_turn_started_count(nil, _make_player({})), 0, "empty status")
    end)

    it("increment returns and persists the new count", function()
      local game = _make_game()
      local player = _make_player({})
      _assert_eq(status_ops.increment_own_turn_started_count(game, player), 1, "first increment")
      _assert_eq(status_ops.increment_own_turn_started_count(game, player), 2, "second increment")
      _assert_eq(status_ops.player_own_turn_started_count(game, player), 2, "reader sees persisted count")
      _assert_eq(game.dirty.players, true, "increment marks players dirty")
    end)
  end)

  describe("one-shot pending flags", function()
    it("has_/consume_pending_free_rent: consume clears the flag exactly once", function()
      local game = _make_game()
      local player = _make_player({ pending_free_rent = true })
      _assert_eq(status_ops.has_pending_free_rent(game, player), true, "flag set")
      _assert_eq(status_ops.consume_pending_free_rent(game, player), true, "first consume hits")
      _assert_eq(status_ops.has_pending_free_rent(game, player), false, "flag cleared")
      _assert_eq(status_ops.consume_pending_free_rent(game, player), false, "second consume misses")
      _assert_eq(game.dirty.players, true, "consume marks players dirty")
    end)

    it("has_/consume_pending_tax_free: consume clears the flag exactly once", function()
      local game = _make_game()
      local player = _make_player({ pending_tax_free = true })
      _assert_eq(status_ops.has_pending_tax_free(game, player), true, "flag set")
      _assert_eq(status_ops.consume_pending_tax_free(game, player), true, "first consume hits")
      _assert_eq(status_ops.has_pending_tax_free(game, player), false, "flag cleared")
      _assert_eq(status_ops.consume_pending_tax_free(game, player), false, "second consume misses")
    end)

    it("consume on unset flag is a no-op that does not mark dirty", function()
      local game = _make_game()
      local player = _make_player(nil)
      _assert_eq(status_ops.consume_pending_free_rent(game, player), false, "unset free rent")
      _assert_eq(status_ops.consume_pending_tax_free(game, player), false, "unset tax free")
      _assert_eq(game.dirty.players, false, "no-op consume must not mark dirty")
    end)
  end)
end)
