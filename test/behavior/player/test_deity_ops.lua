-- 原生 LuaUnit(自研 busted → LuaUnit 迁移):describe 拍平为 TestDeityOps,
-- before_each → setUp,裸 assert(语句位)切 lu.assertEvalToTrue,用例数与改写前
-- 一一对应(30 例)。
local lu = require("luaunit")
local deity_ops = require("src.player.actions.deity")
local monopoly_event = require("src.foundation.events")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
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

TestDeityOps = {}

function TestDeityOps:setUp()
  _config_reset.reset_all()
end

function TestDeityOps:test_player_has_deity_false_when_no_status()
  local player = _make_player()
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "no status should return false")
end

function TestDeityOps:test_player_has_deity_false_when_no_deity_in_status()
  local player = _make_player({ status = {} })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "no deity should return false")
end

function TestDeityOps:test_player_has_deity_false_when_type_mismatch()
  local player = _make_player({ status = { deity = { type = "devil", remaining = 2 } } })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "wrong type should return false")
end

function TestDeityOps:test_player_has_deity_false_when_remaining_zero()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 0 } } })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), false, "remaining=0 should return false")
end

function TestDeityOps:test_player_has_deity_true_when_matching()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
  _assert_eq(deity_ops.player_has_deity(nil, player, "angel"), true, "matching deity with remaining>0 should return true")
end

function TestDeityOps:test_player_deity_type_nil_when_no_active_deity()
  local game = _make_game()
  game.player_has_any_deity = deity_ops.player_has_any_deity
  _assert_eq(deity_ops.player_deity_type(game, _make_player()), nil, "no status should read nil deity type")
  local expired = _make_player({ status = { deity = { type = "rich", remaining = 0 } } })
  _assert_eq(deity_ops.player_deity_type(game, expired), nil, "expired deity should read nil deity type")
end

function TestDeityOps:test_player_deity_type_returns_active_deity_type()
  local game = _make_game()
  game.player_has_any_deity = deity_ops.player_has_any_deity
  local player = _make_player({ status = { deity = { type = "rich", remaining = 2 } } })
  _assert_eq(deity_ops.player_deity_type(game, player), "rich", "active deity should expose its type")
end

function TestDeityOps:test_player_has_angel_delegates_to_player_has_deity()
  local game = _make_game()
  game.player_has_deity = deity_ops.player_has_deity
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.player_has_angel(game, player), true, "player_has_angel should return true for angel")
end

function TestDeityOps:test_player_has_angel_false_for_other_deity()
  local game = _make_game()
  game.player_has_deity = deity_ops.player_has_deity
  local player = _make_player({ status = { deity = { type = "devil", remaining = 1 } } })
  _assert_eq(deity_ops.player_has_angel(game, player), false, "player_has_angel should return false for non-angel")
end

function TestDeityOps:test_clear_player_deity_clears_type_and_remaining()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
  deity_ops.clear_player_deity(game, player)
  _assert_eq(player.status.deity.type, "", "deity type should be cleared")
  _assert_eq(player.status.deity.remaining, 0, "deity remaining should be 0")
  _assert_eq(game.dirty.players, true, "dirty.players should be set")
end

function TestDeityOps:test_clear_player_deity_initializes_deity_if_nil()
  local game = _make_game()
  local player = _make_player({ status = {} })
  deity_ops.clear_player_deity(game, player)
  _assert_eq(player.status.deity.type, "", "deity type should be empty string")
  _assert_eq(player.status.deity.remaining, 0, "deity remaining should be 0")
end

function TestDeityOps:test_set_player_deity_sets_type_and_remaining()
  local game = _make_game()
  local player = _make_player()
  deity_ops.set_player_deity(game, player, "angel", 5)
  _assert_eq(player.status.deity.type, "angel", "deity type should be angel")
  _assert_eq(player.status.deity.remaining, 6, "internal remaining is duration+1")
  _assert_eq(game.dirty.players, true, "dirty.players should be set")
end

function TestDeityOps:test_set_player_deity_uses_player_duration_when_no_duration_arg()
  local game = _make_game()
  local player = _make_player({ deity_duration_turns = 4 })
  deity_ops.set_player_deity(game, player, "devil", nil)
  _assert_eq(player.status.deity.remaining, 5, "internal remaining is deity_duration_turns+1")
end

function TestDeityOps:test_set_player_deity_emits_event()
  local game = _make_game()
  local player = _make_player()
  local emitted = nil
  local saved_emit = monopoly_event.emit
  monopoly_event.emit = function(event_name, payload) emitted = payload end
  deity_ops.set_player_deity(game, player, "angel", 3)
  monopoly_event.emit = saved_emit
  lu.assertEvalToTrue(emitted ~= nil, "should emit event")
  _assert_eq(emitted.deity_type, "angel", "emitted event should have deity_type")
  _assert_eq(emitted.remaining, 3, "emitted event should have remaining")
end

function TestDeityOps:test_transfer_deity_to_deityless_dst_resets_remaining_and_clears_source()
  -- 转移即续神(#529):dst 无神同样重置满时长(duration+1 内部约定),不照抄 src 残余。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "angel", remaining = 2 } } })
  local dst = _make_player({ id = "p2" })
  local ok, err = pcall(function() deity_ops.transfer_deity(game, src, dst) end)
  lu.assertEvalToTrue(ok, "transfer should succeed; err: " .. tostring(err))
  _assert_eq(dst.status.deity.type, "angel", "dst should receive the deity type")
  _assert_eq(dst.status.deity.remaining, 4, "dst remaining resets to full duration+1")
  _assert_eq(src.status.deity.type, "", "src should be cleared")
  _assert_eq(src.status.deity.remaining, 0, "src remaining should be cleared")
end

function TestDeityOps:test_transfer_deity_rejects_source_with_expired_deity()
  -- L90 `_effective_source_deity` 断言条件:`remaining=0` 的源不可转移。
  -- `and->or`(src_deity 恒真放行)/ `(remaining or 0) > 0 -> >=` / `0 -> 1`
  -- 变异体都让断言通过,原实现必须报错拒绝。
  local game = _make_game()
  local expired = _make_player({ id = "p1", status = { deity = { type = "angel", remaining = 0 } } })
  local dst = _make_player({ id = "p2" })
  local ok = pcall(function() deity_ops.transfer_deity(game, expired, dst) end)
  _assert_eq(ok, false, "expired source deity must be rejected")
end

function TestDeityOps:test_transfer_deity_rejects_source_without_remaining_count()
  -- L90 `(src_deity.remaining or 0) > 0` 的 or-default `0 -> 1`:remaining 为
  -- nil 时变异体 `(nil or 1) > 0` 放行,原实现 `(nil or 0) > 0` 必须拒绝。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "angel" } } })
  local dst = _make_player({ id = "p2" })
  local ok = pcall(function() deity_ops.transfer_deity(game, src, dst) end)
  _assert_eq(ok, false, "source deity without remaining must be rejected")
end

function TestDeityOps:test_transfer_deity_accepts_source_with_single_remaining_turn()
  -- L90 `(src_deity.remaining or 0) > 0` 的比较界 `0 -> 1`:remaining=1 的
  -- 源原实现有效(1 > 0),变异体 `1 > 1` 误拒绝。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "angel", remaining = 1 } } })
  local dst = _make_player({ id = "p2" })
  local ok, err = pcall(function() deity_ops.transfer_deity(game, src, dst) end)
  lu.assertEvalToTrue(ok, "single-turn source deity must be transferable; err: " .. tostring(err))
  _assert_eq(dst.status.deity.remaining, 4, "transfer resets remaining to full duration+1")
end

function TestDeityOps:test_transfer_deity_emits_deity_applied_with_dst_player_id()
  -- `_emit_deity_applied` `player and player.id or nil` 的 `and->or`(player_id 变整个
  -- dst 表)/ `or->and`(player_id 恒 nil):事件观察者必须拿到真实 id 才能分派。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "rich", remaining = 3 } } })
  local dst = _make_player({ id = "p2", deity_duration_turns = 10 })
  local emitted = nil
  local saved_emit = monopoly_event.emit
  monopoly_event.emit = function(event_name, payload) emitted = payload end
  deity_ops.transfer_deity(game, src, dst)
  monopoly_event.emit = saved_emit
  lu.assertEvalToTrue(emitted ~= nil, "transfer should emit deity_applied")
  _assert_eq(emitted.player_id, dst.id, "emitted player_id must be the dst id")
  _assert_eq(emitted.deity_type, "rich", "emitted deity_type must carry over")
  _assert_eq(emitted.remaining, 10, "emitted remaining must be the nominal full duration")
end

function TestDeityOps:test_transfer_deity_resets_remaining_when_dst_has_same_deity()
  -- 同神转移=续神:dst 剩余回合重置为满时长(duration+1 内部约定,同
  -- set_player_deity),不照抄 src 残余——否则请到同神反而缩短自己的附身。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "rich", remaining = 3 } } })
  local dst = _make_player({ id = "p2", deity_duration_turns = 10, status = { deity = { type = "rich", remaining = 9 } } })
  deity_ops.transfer_deity(game, src, dst)
  _assert_eq(dst.status.deity.type, "rich", "dst keeps the deity type")
  _assert_eq(dst.status.deity.remaining, 11, "same-deity transfer resets remaining to full duration+1")
  _assert_eq(src.status.deity.type, "", "src should be cleared")
  _assert_eq(src.status.deity.remaining, 0, "src remaining should be cleared")
end

function TestDeityOps:test_transfer_deity_resets_remaining_when_dst_has_other_deity()
  -- 异神转移同样续神(#529):换神且剩余回合重置满时长,不照抄 src 残余。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "rich", remaining = 3 } } })
  local dst = _make_player({ id = "p2", status = { deity = { type = "angel", remaining = 9 } } })
  deity_ops.transfer_deity(game, src, dst)
  _assert_eq(dst.status.deity.type, "rich", "dst deity replaced by src type")
  _assert_eq(dst.status.deity.remaining, 4, "different-deity transfer also resets to full duration+1")
end

function TestDeityOps:test_transfer_deity_resets_remaining_when_dst_deity_expired_placeholder()
  -- dst 仅有失效占位(remaining=0)同样重置满时长(#529 不再分同神/异神/无神)。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "rich", remaining = 3 } } })
  local dst = _make_player({ id = "p2", status = { deity = { type = "rich", remaining = 0 } } })
  deity_ops.transfer_deity(game, src, dst)
  _assert_eq(dst.status.deity.remaining, 4, "expired placeholder does not block full-duration reset")
end

function TestDeityOps:test_transfer_deity_same_deity_emits_reset_remaining()
  -- 同神重置的事件载荷与 set_player_deity 同约定:remaining 报名义时长,
  -- 不报内部 +1 值,也不报 src 残余。
  local game = _make_game()
  local src = _make_player({ id = "p1", status = { deity = { type = "rich", remaining = 3 } } })
  local dst = _make_player({ id = "p2", deity_duration_turns = 10, status = { deity = { type = "rich", remaining = 9 } } })
  local emitted = nil
  local saved_emit = monopoly_event.emit
  monopoly_event.emit = function(event_name, payload) emitted = payload end
  deity_ops.transfer_deity(game, src, dst)
  monopoly_event.emit = saved_emit
  lu.assertEvalToTrue(emitted ~= nil, "transfer should emit deity_applied")
  _assert_eq(emitted.remaining, 10, "reset transfer should emit nominal full duration")
end

function TestDeityOps:test_set_player_deity_errors_when_name_nil()
  local game = _make_game()
  local player = _make_player()
  local ok = pcall(function() deity_ops.set_player_deity(game, player, nil, 3) end)
  _assert_eq(ok, false, "nil name should error")
end

function TestDeityOps:test_tick_player_deity_decrements_remaining()
  local game = _make_game()
  game.player_has_deity = deity_ops.player_has_deity
  local player = _make_player({ status = { deity = { type = "angel", remaining = 3 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 2, "tick should decrement remaining")
end

function TestDeityOps:test_tick_player_deity_no_effect_when_remaining_zero()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 0 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 0, "no tick when remaining is 0")
  _assert_eq(game.dirty.players, false, "dirty.players should not be set when remaining=0")
end

function TestDeityOps:test_tick_player_deity_clears_when_reaches_zero()
  local game = _make_game()
  game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 0, "deity should be cleared when reaching 0")
  _assert_eq(player.status.deity.type, "", "deity type should be cleared")
end

function TestDeityOps:test_tick_player_deity_marks_dirty_when_remaining_stays_positive()
  local game = _make_game()
  game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
  local player = _make_player({ status = { deity = { type = "angel", remaining = 2 } } })
  deity_ops.tick_player_deity(game, player)
  _assert_eq(game.dirty.players, true, "dirty.players should be set when remaining > 0 after tick")
end

function TestDeityOps:test_activation_turn_tick_brings_remaining_to_nominal_duration()
  local game = _make_game()
  game.clear_player_deity = function(self, p) deity_ops.clear_player_deity(self, p) end
  local player = _make_player({ deity_duration_turns = 10 })
  deity_ops.set_player_deity(game, player, "rich", nil)
  deity_ops.tick_player_deity(game, player)
  _assert_eq(player.status.deity.remaining, 10, "after activation-turn tick, remaining should equal duration")
  _assert_eq(player.status.deity.type, "rich", "deity type should persist")
end

function TestDeityOps:test_deity_lasts_exactly_n_effective_turns_after_activation()
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
end


return TestDeityOps
