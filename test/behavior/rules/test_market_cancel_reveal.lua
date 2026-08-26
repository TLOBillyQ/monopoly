-- market_buy 取消路径:撤掉「商店抽到道具」的揭示动画。
-- 覆盖 _clear_market_item_reveals / _remove_market_reveals_from_queue 的
-- 队列删除、非表队列、无 turn 等分支。
-- 2026-08-22 #543:揭示动画统一为 item_gain_popup 纯等待动画,识别仍靠
-- kind + source=="market" 双条件。
local market_handlers = require("src.rules.choice_handlers.market")
local event_kinds = require("src.config.gameplay.event_kinds")

-- 原生 LuaUnit 转换(busted → LuaUnit):describe 拍平为文件级 Test 类,
-- before_each → setUp,断言词汇切到 lu.assertXxx,用例数与改写前一一对应(5 例)。

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- 取出注册表里 market_buy 的 cancel.resolve。
local function _cancel_resolve()
  local registry = {}
  market_handlers.register(registry, { finish_choice = function() end })
  return registry.market_buy.cancel.resolve
end

local function _market_reveal()
  return { kind = event_kinds.item_gain_popup, source = "market" }
end

local function _make_game(turn)
  return { turn = turn, dirty = {} }
end

local _config_reset = require("test.support.config_reset")

TestMarketCancelReveal = {}

function TestMarketCancelReveal:setUp()
  _config_reset.reset_all()
end

function TestMarketCancelReveal:test_clears_the_reveal_that_is_currently_playing()
  local game = _make_game({ action_anim = _market_reveal() })

  _cancel_resolve()(game)

  _assert_eq(game.turn.action_anim, nil, "the playing market reveal should be dropped")
  _assert_eq(game.dirty.turn, true, "dropping a reveal should mark turn dirty")
end

function TestMarketCancelReveal:test_removes_queued_market_reveals_and_keeps_everything_else()
  local keep_other_source = { kind = event_kinds.item_gain_popup, source = "chance" }
  local keep_other_kind = { kind = "move", source = "market" }
  local game = _make_game({
    action_anim_queue = { _market_reveal(), keep_other_source, _market_reveal(), keep_other_kind },
  })

  _cancel_resolve()(game)

  local queue = game.turn.action_anim_queue
  _assert_eq(#queue, 2, "both market reveals should be removed from the queue")
  _assert_eq(queue[1], keep_other_source, "a non-market reveal must survive")
  _assert_eq(queue[2], keep_other_kind, "a non-reveal anim must survive")
  _assert_eq(game.dirty.turn, true, "removing queued reveals should mark turn dirty")
end

function TestMarketCancelReveal:test_leaves_the_turn_untouched_when_there_is_no_market_reveal_anywhere()
  local other = { kind = "move", source = "market" }
  local game = _make_game({ action_anim = other, action_anim_queue = { other } })

  _cancel_resolve()(game)

  _assert_eq(game.turn.action_anim, other, "an unrelated anim must keep playing")
  _assert_eq(#game.turn.action_anim_queue, 1, "an unrelated queued anim must survive")
  _assert_eq(game.dirty.turn, nil, "nothing removed means turn is not marked dirty")
end

function TestMarketCancelReveal:test_tolerates_a_turn_whose_anim_queue_is_not_a_table()
  local game = _make_game({ action_anim = _market_reveal(), action_anim_queue = "not_a_table" })

  _cancel_resolve()(game)

  _assert_eq(game.turn.action_anim, nil, "the playing reveal should still be dropped")
  _assert_eq(game.dirty.turn, true, "dropping the playing reveal still marks turn dirty")
end

function TestMarketCancelReveal:test_is_a_no_op_when_the_game_has_no_turn()
  local game = _make_game(nil)

  _cancel_resolve()(game)

  _assert_eq(game.dirty.turn, nil, "no turn means nothing to clear and nothing to mark")
end


return TestMarketCancelReveal
