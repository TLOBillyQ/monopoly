---@diagnostic disable: undefined-field

-- 原生 LuaUnit(自研 busted → LuaUnit 迁移):describe 拍平为 TestDeityHelpers,
-- before_each → setUp,断言词汇切到 lu.assertXxx / luax.has_error 补件,用例数与
-- 改写前一一对应(19 例)。
local lu = require("luaunit")
local luax = require("test.support.luax")
local deity_ops = require("src.player.actions.deity")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_player(opts)
  opts = opts or {}
  return {
    id = opts.id or "p1",
    status = opts.status or nil,
    deity_duration_turns = opts.deity_duration_turns or 3,
  }
end

TestDeityHelpers = {}

function TestDeityHelpers:setUp()
  _config_reset.reset_all()
end

function TestDeityHelpers:test_player_has_any_deity_false_when_no_status()
  local player = _make_player()
  _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "no status should return false")
end

function TestDeityHelpers:test_player_has_any_deity_false_when_no_deity_in_status()
  local player = _make_player({ status = {} })
  _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "no deity should return false")
end

function TestDeityHelpers:test_player_has_any_deity_false_for_cleared_placeholder()
  local player = _make_player({ status = { deity = { type = "", remaining = 0 } } })
  _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "cleared placeholder should return false")
end

function TestDeityHelpers:test_player_has_any_deity_false_for_exhausted_poor_deity()
  local player = _make_player({ status = { deity = { type = "poor", remaining = 0 } } })
  _assert_eq(deity_ops.player_has_any_deity(nil, player), false, "remaining=0 should return false")
end

function TestDeityHelpers:test_player_has_any_deity_true_for_poor_deity()
  local player = _make_player({ status = { deity = { type = "poor", remaining = 5 } } })
  _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "poor deity should return true")
end

function TestDeityHelpers:test_player_has_any_deity_true_for_rich_deity()
  local player = _make_player({ status = { deity = { type = "rich", remaining = 1 } } })
  _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "rich deity should return true")
end

function TestDeityHelpers:test_player_has_any_deity_true_for_angel_deity()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 3 } } })
  _assert_eq(deity_ops.player_has_any_deity(nil, player), true, "angel deity should return true")
end

function TestDeityHelpers:test_game_exposes_player_has_any_deity_mixin()
  local support = require("test.support.shared_support")
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  lu.assertIsFunction(game.player_has_any_deity)
end

function TestDeityHelpers:test_transfer_deity_moves_effective_deity_from_source_to_destination()
  local game = { dirty = {} }
  game.set_player_deity = deity_ops.set_player_deity
  game.clear_player_deity = deity_ops.clear_player_deity
  local src = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })
  local dst = _make_player({ id = "B" })

  lu.assertTrue(deity_ops.transfer_deity(game, src, dst))

  _assert_eq(src.status.deity.type, "", "src deity type should be cleared")
  _assert_eq(src.status.deity.remaining, 0, "src deity remaining should be zeroed")
  _assert_eq(dst.status.deity.type, "poor", "dst deity type should be transferred")
  _assert_eq(dst.status.deity.remaining, 4, "dst deity remaining resets to full duration+1 (#529)")
end

function TestDeityHelpers:test_transfer_deity_rejects_self_transfer()
  local game = { dirty = {} }
  game.set_player_deity = deity_ops.set_player_deity
  game.clear_player_deity = deity_ops.clear_player_deity
  local player = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })

  luax.has_error(function() deity_ops.transfer_deity(game, player, player) end, "cannot transfer to self")
end

function TestDeityHelpers:test_transfer_deity_rejects_empty_source_deity()
  local game = { dirty = {} }
  game.set_player_deity = deity_ops.set_player_deity
  game.clear_player_deity = deity_ops.clear_player_deity
  local src = _make_player({ id = "A", status = { deity = { type = "", remaining = 0 } } })
  local dst = _make_player({ id = "B" })

  luax.has_error(function() deity_ops.transfer_deity(game, src, dst) end, "src has no effective deity")
end

function TestDeityHelpers:test_transfer_deity_overwrites_existing_destination_deity()
  local game = { dirty = {} }
  game.set_player_deity = deity_ops.set_player_deity
  game.clear_player_deity = deity_ops.clear_player_deity
  local src = _make_player({ id = "B", status = { deity = { type = "poor", remaining = 5 } } })
  local dst = _make_player({ id = "A", status = { deity = { type = "rich", remaining = 3 } } })

  lu.assertTrue(deity_ops.transfer_deity(game, src, dst))

  _assert_eq(dst.status.deity.type, "poor", "dst deity should be overwritten")
  _assert_eq(dst.status.deity.remaining, 4, "dst remaining resets to full duration+1 (#529)")
  _assert_eq(src.status.deity.type, "", "src deity type should be cleared")
  _assert_eq(src.status.deity.remaining, 0, "src deity remaining should be zeroed")
end

function TestDeityHelpers:test_transfer_deity_raises_guard_flag_only_during_transfer()
  local saw_guard = false
  local game = { dirty = {} }
  game.clear_player_deity = function(self, player)
    saw_guard = self._deity_transferring == true
    return deity_ops.clear_player_deity(self, player)
  end
  local src = _make_player({ id = "A", status = { deity = { type = "poor", remaining = 5 } } })
  local dst = _make_player({ id = "B" })

  lu.assertTrue(deity_ops.transfer_deity(game, src, dst))

  lu.assertTrue(saw_guard)
  _assert_eq(game._deity_transferring, false, "guard should be false after transfer")
end

function TestDeityHelpers:test_game_exposes_transfer_deity_mixin()
  local support = require("test.support.shared_support")
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  lu.assertIsFunction(game.transfer_deity)
end

function TestDeityHelpers:test_set_player_deity_rejects_empty_deity_name()
  local game = { dirty = {} }
  local player = _make_player()

  luax.has_error(function() deity_ops.set_player_deity(game, player, "", 5) end, "deity name must be non-empty string")
end

function TestDeityHelpers:test_set_player_deity_rejects_zero_duration()
  local game = { dirty = {} }
  local player = _make_player()

  luax.has_error(function() deity_ops.set_player_deity(game, player, "poor", 0) end, "explicit duration must be positive")
end

function TestDeityHelpers:test_set_player_deity_rejects_negative_duration()
  local game = { dirty = {} }
  local player = _make_player()

  luax.has_error(function() deity_ops.set_player_deity(game, player, "poor", -1) end, "explicit duration must be positive")
end

function TestDeityHelpers:test_tick_player_deity_leaves_eliminated_remaining_unchanged()
  local game = { dirty = {} }
  game.clear_player_deity = deity_ops.clear_player_deity
  game.mark_players = function() error("should not mark eliminated player") end
  local player = _make_player({ status = { deity = { type = "poor", remaining = 4 } } })
  player.eliminated = true

  deity_ops.tick_player_deity(game, player)

  _assert_eq(player.status.deity.remaining, 4, "eliminated player should not tick down")
end

function TestDeityHelpers:test_tick_player_deity_ignores_eliminated_player_with_residual_deity()
  local game = { dirty = {} }
  game.clear_player_deity = deity_ops.clear_player_deity
  game.mark_players = function() error("should not mark eliminated player") end
  local player = _make_player({ status = { deity = { type = "poor", remaining = 1 } } })
  player.eliminated = true

  luax.has_no_error(function() deity_ops.tick_player_deity(game, player) end)
  _assert_eq(player.status.deity.type, "poor", "residual deity should stay intact")
  _assert_eq(player.status.deity.remaining, 1, "residual deity should remain unchanged")
end


return TestDeityHelpers
