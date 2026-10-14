require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local status_ops = require("src.player.actions.status")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  luassert.truthy(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  return { dirty = { any = false, players = false } }
end

local function _make_player(status)
  return { id = "p1", name = "P1", status = status }
end

describe("TestStatusOps", function()

  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_peek_normalizes_unset_nil_status_to_1", function()
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player(nil)), 1, "nil status")
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({})), 1, "empty status")
  end)

  it("test_peek_normalizes_values_le_1_to_1", function()
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({ pending_dice_multiplier = 1 })), 1, "1")
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({ pending_dice_multiplier = 0 })), 1, "0")
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, _make_player({ pending_dice_multiplier = 0.5 })), 1,
      "any value <= 1 is no multiplier")
  end)

  it("test_peek_returns_pending_multiplier_without_clearing", function()
    local player = _make_player({ pending_dice_multiplier = 4 })
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, player), 4, "peek")
    _assert_eq(status_ops.player_pending_dice_multiplier(nil, player), 4, "peek must not consume")
  end)

  it("test_consume_returns_multiplier_and_resets_it_to_1", function()
    local game = _make_game()
    local player = _make_player({ pending_dice_multiplier = 3 })
    _assert_eq(status_ops.consume_pending_dice_multiplier(game, player), 3, "consume returns value")
    _assert_eq(status_ops.player_pending_dice_multiplier(game, player), 1, "consumed multiplier reads 1")
    -- owning-layer layout pin: consume must store the canonical 1 (same value
    -- clear_player_temporal_flags writes), not merely a value that normalizes to 1.
    _assert_eq(player.status.pending_dice_multiplier, 1, "consume stores canonical 1")
    _assert_eq(game.dirty.players, true, "consume marks players dirty")
  end)

  it("test_peek_returns_nil_when_nothing_pending", function()
    _assert_eq(status_ops.peek_pending_remote_dice(nil, _make_player(nil)), nil, "nil status")
    _assert_eq(status_ops.peek_pending_remote_dice(nil, _make_player({})), nil, "empty status")
  end)

  it("test_set_then_peek_round_trips_without_consuming", function()
    local game = _make_game()
    local player = _make_player({})
    status_ops.set_pending_remote_dice(game, player, { 4, 4 })
    local values = status_ops.peek_pending_remote_dice(game, player)
    _assert_eq(values ~= nil and values[1], 4, "first value")
    _assert_eq(values ~= nil and values[2], 4, "second value")
    _assert_eq(status_ops.peek_pending_remote_dice(game, player) ~= nil, true, "peek must not consume")
    _assert_eq(game.dirty.players, true, "set marks players dirty")
  end)

  it("test_set_rejects_empty_values", function()
    local ok = pcall(status_ops.set_pending_remote_dice, _make_game(), _make_player({}), {})
    _assert_eq(ok, false, "empty values must be rejected")
  end)

  it("test_remaining_is_0_when_never_detained_or_counter_non_positive", function()
    _assert_eq(status_ops.detention_remaining(nil, _make_player(nil)), 0, "nil status")
    _assert_eq(status_ops.detention_remaining(nil, _make_player({ stay_turns = 0 })), 0, "zero")
    _assert_eq(status_ops.detention_remaining(nil, _make_player({ stay_turns = -1 })), 0, "negative clamps to 0")
  end)

  it("test_remaining_stays_ge_1_across_2_turn_stay_and_only_hits_0_on_release", function()
    local game = _make_game()
    local player = _make_player({ stay_turns = 2 })
    _assert_eq(status_ops.detention_remaining(game, player), 2, "before first frozen turn")
    _assert_eq(status_ops.consume_detention_turn(game, player), 2, "first frozen turn shows inclusive 2")
    _assert_eq(status_ops.detention_remaining(game, player), 1, "still detained after first turn")
    _assert_eq(status_ops.consume_detention_turn(game, player), 1, "last frozen turn shows inclusive 1, never 0")
    _assert_eq(status_ops.detention_remaining(game, player), 0, "released once counter reaches 0")
  end)

  it("test_consume_on_free_player_returns_0_and_does_not_go_negative", function()
    local game = _make_game()
    local player = _make_player({ stay_turns = 0 })
    _assert_eq(status_ops.consume_detention_turn(game, player), 0, "free player consumes nothing")
    _assert_eq(status_ops.detention_remaining(game, player), 0, "remaining stays 0")
    _assert_eq(game.dirty.players, false, "no-op consume must not mark dirty")
  end)

  it("test_consume_marks_players_dirty_when_detention_turn_spent", function()
    local game = _make_game()
    local player = _make_player({ stay_turns = 1 })
    status_ops.consume_detention_turn(game, player)
    _assert_eq(game.dirty.players, true, "consume marks players dirty")
  end)

  it("test_own_turn_started_count_reads_0_when_unset", function()
    _assert_eq(status_ops.player_own_turn_started_count(nil, _make_player(nil)), 0, "nil status")
    _assert_eq(status_ops.player_own_turn_started_count(nil, _make_player({})), 0, "empty status")
  end)

  it("test_increment_own_turn_started_count_returns_and_persists_new_count", function()
    local game = _make_game()
    local player = _make_player({})
    _assert_eq(status_ops.increment_own_turn_started_count(game, player), 1, "first increment")
    _assert_eq(status_ops.increment_own_turn_started_count(game, player), 2, "second increment")
    _assert_eq(status_ops.player_own_turn_started_count(game, player), 2, "reader sees persisted count")
    _assert_eq(game.dirty.players, true, "increment marks players dirty")
  end)

  it("test_consume_pending_free_rent_clears_flag_exactly_once", function()
    local game = _make_game()
    local player = _make_player({ pending_free_rent = true })
    _assert_eq(status_ops.has_pending_free_rent(game, player), true, "flag set")
    _assert_eq(status_ops.consume_pending_free_rent(game, player), true, "first consume hits")
    _assert_eq(status_ops.has_pending_free_rent(game, player), false, "flag cleared")
    _assert_eq(status_ops.consume_pending_free_rent(game, player), false, "second consume misses")
    _assert_eq(game.dirty.players, true, "consume marks players dirty")
  end)

  it("test_consume_pending_tax_free_clears_flag_exactly_once", function()
    local game = _make_game()
    local player = _make_player({ pending_tax_free = true })
    _assert_eq(status_ops.has_pending_tax_free(game, player), true, "flag set")
    _assert_eq(status_ops.consume_pending_tax_free(game, player), true, "first consume hits")
    _assert_eq(status_ops.has_pending_tax_free(game, player), false, "flag cleared")
    _assert_eq(status_ops.consume_pending_tax_free(game, player), false, "second consume misses")
  end)

  it("test_consume_on_unset_flag_is_noop_without_marking_dirty", function()
    local game = _make_game()
    local player = _make_player(nil)
    _assert_eq(status_ops.consume_pending_free_rent(game, player), false, "unset free rent")
    _assert_eq(status_ops.consume_pending_tax_free(game, player), false, "unset tax free")
    _assert_eq(game.dirty.players, false, "no-op consume must not mark dirty")
  end)


end)
