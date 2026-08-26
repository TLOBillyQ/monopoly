local support = require("test.support.shared_support")
local logger = require("src.foundation.log")

local turn_timer_policy = require("src.turn.policies.timer")
local tip_queue = require("src.foundation.tips")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _reset_tip_queue()
  tip_queue.clear()
  tip_queue.configure_runtime({ clear_presenter = true, clear_scheduler = true })
end

TestTurnTimerPolicy = {}

function TestTurnTimerPolicy:tearDown()
  -- 清了共享 tips 基线必须装回,否则 mutate 车道窄 suite 子集撞空 presenter(#217)
  support.restore_runtime_services()
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_no_args_returns_false()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  _assert_eq(turn_timer_policy.is_action_button_wait_active(nil, nil, nil), false, "nil args should return false")
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_finished_game_returns_false()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { finished = true, turn = {} }
  local state = {}
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, { ui_sync = nil }), false, "finished game should return false")
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_pending_choice_returns_false()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = { pending_choice = { kind = "market_buy" } } }
  local state = {}
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, { ui_sync = nil }), false, "pending_choice should return false")
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_no_blocking_ui_returns_true()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = {} }
  local state = {}
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, { ui_sync = nil }), true, "no blocking ui should return true")
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_choice_active_returns_false()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = {} }
  local state = {}
  local ports = {
    ui_sync = {
      is_choice_active = function() return true end,
    },
  }
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, ports), false, "choice active should return false")
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_input_blocked_returns_false()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = {} }
  local state = {}
  local ports = {
    ui_sync = {
      is_input_blocked = function() return true end,
    },
  }
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, ports), false, "input blocked should return false")
end

function TestTurnTimerPolicy:test_is_action_button_wait_active_ui_state_absent_returns_false()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = {} }
  local state = {}
  local ports = {
    ui_sync = {
      get_ui_state = function() return nil end,
    },
  }
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, ports), false, "absent ui_state should return false")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_no_game_noop()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  -- should not error
  turn_timer_policy.update_detained_wait_timer(nil, nil, 0.1, function() end)
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_no_detained_wait_noop()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = false } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, false, "no detained_wait_active should be noop")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_zero_timeout_fires()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, true, "zero timeout should fire step_turn")
  _assert_eq(game.turn.detained_wait_active, false, "detained_wait_active should be cleared")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_elapsed_below_timeout_increments()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 5, detained_wait_elapsed = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, false, "elapsed < timeout should not fire")
  _assert_eq(game.turn.detained_wait_elapsed, 1.0, "elapsed should be updated")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_elapsed_exceeds_timeout_fires()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 2, detained_wait_elapsed = 1.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, true, "elapsed >= timeout should fire step_turn")
  _assert_eq(game.turn.detained_wait_active, false, "detained_wait_active should be cleared")
  _assert_eq(game.turn.detained_wait_elapsed, 0, "elapsed should be reset")
end

function TestTurnTimerPolicy:test_update_inter_turn_wait_timer_no_turn_noop()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  local game = { turn = { inter_turn_wait_active = false } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, false, "no inter_turn_wait_active should be noop")
end

function TestTurnTimerPolicy:test_update_inter_turn_wait_timer_zero_timeout_fires()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  _reset_tip_queue()
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, true, "zero timeout should fire step_turn")
  _assert_eq(game.turn.inter_turn_wait_active, false, "inter_turn_wait_active should be cleared")
  _reset_tip_queue()
end

function TestTurnTimerPolicy:test_update_inter_turn_wait_timer_elapsed_below_timeout_increments()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  _reset_tip_queue()
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 5, inter_turn_wait_elapsed = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, false, "elapsed < timeout should not fire")
  _assert_eq(game.turn.inter_turn_wait_elapsed, 1.0, "elapsed should be updated")
  _reset_tip_queue()
end

function TestTurnTimerPolicy:test_update_inter_turn_wait_timer_elapsed_exceeds_no_blocking_tip_fires()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  _reset_tip_queue()
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 2, inter_turn_wait_elapsed = 1.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, true, "elapsed >= timeout with no blocking tip should fire")
  _assert_eq(game.turn.inter_turn_wait_active, false, "should be cleared")
  _reset_tip_queue()
end

function TestTurnTimerPolicy:test_update_inter_turn_wait_timer_elapsed_exceeds_blocking_tip_defers()
  -- migrated wrap: 见 commit 说明，原 wrap 在 it body 首行注入
  logger.set_test_mode(false)
  _reset_tip_queue()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function() return true end,
  })
  tip_queue.enqueue({ text = "block", duration = 5.0, blocks_inter_turn = true })
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 2, inter_turn_wait_elapsed = 1.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, false, "blocking tip should defer step_turn")
  _assert_eq(game.turn.inter_turn_wait_active, true, "active should remain true when deferred")
  _reset_tip_queue()
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_nil_state_noop()
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 0 } }
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, nil, 0.1, function() called = true end)
  _assert_eq(called, false, "nil state should not step the turn")
  _assert_eq(game.turn.detained_wait_active, true, "nil state should leave the wait untouched")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_missing_timeout_fires_immediately()
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.5, function() called = true end)
  _assert_eq(called, true, "missing timeout should default to zero and fire")
  _assert_eq(game.turn.detained_wait_active, false, "detained_wait_active should be cleared")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_fractional_timeout_waits()
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 0.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, false, "a positive fractional timeout must wait, not fire")
  _assert_eq(game.turn.detained_wait_elapsed, 0.1, "elapsed should accumulate below the timeout")
end

function TestTurnTimerPolicy:test_update_detained_wait_timer_elapsed_reaching_timeout_exactly_fires()
  logger.set_test_mode(false)
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 2, detained_wait_elapsed = 1.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.5, function() called = true end)
  _assert_eq(called, true, "elapsed == timeout should fire step_turn")
  _assert_eq(game.turn.detained_wait_active, false, "detained_wait_active should be cleared")
  _assert_eq(game.turn.detained_wait_elapsed, 0, "elapsed should be reset")
end

function TestTurnTimerPolicy:test_update_inter_turn_wait_timer_zero_timeout_fires_without_consulting_tips()
  logger.set_test_mode(false)
  _reset_tip_queue()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function() return true end,
  })
  tip_queue.enqueue({ text = "block", duration = 5.0, blocks_inter_turn = true })
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, true, "zero timeout should fire even while a blocking tip pends")
  _assert_eq(game.turn.inter_turn_wait_active, false, "active should be cleared on the zero-timeout path")
  _reset_tip_queue()
end


return TestTurnTimerPolicy
