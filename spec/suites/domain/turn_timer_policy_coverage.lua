local turn_timer_policy = require("src.turn.policies.timer")
local tip_queue = require("src.foundation.coordination.tip_queue")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _reset_tip_queue()
  tip_queue.clear()
  tip_queue.configure_runtime({ clear_presenter = true, clear_scheduler = true })
end

-- is_action_button_wait_active

local function test_is_action_button_wait_active_no_args_returns_false()
  _assert_eq(turn_timer_policy.is_action_button_wait_active(nil, nil, nil), false, "nil args should return false")
end

local function test_is_action_button_wait_active_finished_game_returns_false()
  local game = { finished = true, turn = {} }
  local state = {}
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, { ui_sync = nil }), false, "finished game should return false")
end

local function test_is_action_button_wait_active_pending_choice_returns_false()
  local game = { turn = { pending_choice = { kind = "market_buy" } } }
  local state = {}
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, { ui_sync = nil }), false, "pending_choice should return false")
end

local function test_is_action_button_wait_active_no_blocking_ui_returns_true()
  local game = { turn = {} }
  local state = {}
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, { ui_sync = nil }), true, "no blocking ui should return true")
end

local function test_is_action_button_wait_active_choice_active_returns_false()
  local game = { turn = {} }
  local state = {}
  local ports = {
    ui_sync = {
      is_choice_active = function() return true end,
    },
  }
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, ports), false, "choice active should return false")
end

local function test_is_action_button_wait_active_input_blocked_returns_false()
  local game = { turn = {} }
  local state = {}
  local ports = {
    ui_sync = {
      is_input_blocked = function() return true end,
    },
  }
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, ports), false, "input blocked should return false")
end

local function test_is_action_button_wait_active_ui_state_absent_returns_false()
  local game = { turn = {} }
  local state = {}
  local ports = {
    ui_sync = {
      get_ui_state = function() return nil end,
    },
  }
  _assert_eq(turn_timer_policy.is_action_button_wait_active(game, state, ports), false, "absent ui_state should return false")
end

-- update_detained_wait_timer

local function test_update_detained_wait_timer_no_game_noop()
  -- should not error
  turn_timer_policy.update_detained_wait_timer(nil, nil, 0.1, function() end)
end

local function test_update_detained_wait_timer_no_detained_wait_noop()
  local game = { turn = { detained_wait_active = false } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, false, "no detained_wait_active should be noop")
end

local function test_update_detained_wait_timer_zero_timeout_fires()
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, true, "zero timeout should fire step_turn")
  _assert_eq(game.turn.detained_wait_active, false, "detained_wait_active should be cleared")
end

local function test_update_detained_wait_timer_elapsed_below_timeout_increments()
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 5, detained_wait_elapsed = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, false, "elapsed < timeout should not fire")
  _assert_eq(game.turn.detained_wait_elapsed, 1.0, "elapsed should be updated")
end

local function test_update_detained_wait_timer_elapsed_exceeds_timeout_fires()
  local game = { turn = { detained_wait_active = true, detained_wait_seconds = 2, detained_wait_elapsed = 1.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_detained_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, true, "elapsed >= timeout should fire step_turn")
  _assert_eq(game.turn.detained_wait_active, false, "detained_wait_active should be cleared")
  _assert_eq(game.turn.detained_wait_elapsed, 0, "elapsed should be reset")
end

-- update_inter_turn_wait_timer

local function test_update_inter_turn_wait_timer_no_turn_noop()
  local game = { turn = { inter_turn_wait_active = false } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, false, "no inter_turn_wait_active should be noop")
end

local function test_update_inter_turn_wait_timer_zero_timeout_fires()
  _reset_tip_queue()
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 0.1, function() called = true end)
  _assert_eq(called, true, "zero timeout should fire step_turn")
  _assert_eq(game.turn.inter_turn_wait_active, false, "inter_turn_wait_active should be cleared")
  _reset_tip_queue()
end

local function test_update_inter_turn_wait_timer_elapsed_below_timeout_increments()
  _reset_tip_queue()
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 5, inter_turn_wait_elapsed = 0 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, false, "elapsed < timeout should not fire")
  _assert_eq(game.turn.inter_turn_wait_elapsed, 1.0, "elapsed should be updated")
  _reset_tip_queue()
end

local function test_update_inter_turn_wait_timer_elapsed_exceeds_no_blocking_tip_fires()
  _reset_tip_queue()
  local game = { turn = { inter_turn_wait_active = true, inter_turn_wait_seconds = 2, inter_turn_wait_elapsed = 1.5 } }
  local state = {}
  local called = false
  turn_timer_policy.update_inter_turn_wait_timer(game, state, 1.0, function() called = true end)
  _assert_eq(called, true, "elapsed >= timeout with no blocking tip should fire")
  _assert_eq(game.turn.inter_turn_wait_active, false, "should be cleared")
  _reset_tip_queue()
end

local function test_update_inter_turn_wait_timer_elapsed_exceeds_blocking_tip_defers()
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

return {
  name = "domain turn timer policy coverage",
  tests = {
    { name = "is_action_button_wait_active no args returns false", run = test_is_action_button_wait_active_no_args_returns_false },
    { name = "is_action_button_wait_active finished game returns false", run = test_is_action_button_wait_active_finished_game_returns_false },
    { name = "is_action_button_wait_active pending_choice returns false", run = test_is_action_button_wait_active_pending_choice_returns_false },
    { name = "is_action_button_wait_active no blocking ui returns true", run = test_is_action_button_wait_active_no_blocking_ui_returns_true },
    { name = "is_action_button_wait_active choice active returns false", run = test_is_action_button_wait_active_choice_active_returns_false },
    { name = "is_action_button_wait_active input blocked returns false", run = test_is_action_button_wait_active_input_blocked_returns_false },
    { name = "is_action_button_wait_active ui_state absent returns false", run = test_is_action_button_wait_active_ui_state_absent_returns_false },
    { name = "update_detained_wait_timer no game noop", run = test_update_detained_wait_timer_no_game_noop },
    { name = "update_detained_wait_timer no detained_wait noop", run = test_update_detained_wait_timer_no_detained_wait_noop },
    { name = "update_detained_wait_timer zero timeout fires", run = test_update_detained_wait_timer_zero_timeout_fires },
    { name = "update_detained_wait_timer elapsed below timeout increments", run = test_update_detained_wait_timer_elapsed_below_timeout_increments },
    { name = "update_detained_wait_timer elapsed exceeds timeout fires", run = test_update_detained_wait_timer_elapsed_exceeds_timeout_fires },
    { name = "update_inter_turn_wait_timer no turn noop", run = test_update_inter_turn_wait_timer_no_turn_noop },
    { name = "update_inter_turn_wait_timer zero timeout fires", run = test_update_inter_turn_wait_timer_zero_timeout_fires },
    { name = "update_inter_turn_wait_timer elapsed below timeout increments", run = test_update_inter_turn_wait_timer_elapsed_below_timeout_increments },
    { name = "update_inter_turn_wait_timer elapsed exceeds no blocking tip fires", run = test_update_inter_turn_wait_timer_elapsed_exceeds_no_blocking_tip_fires },
    { name = "update_inter_turn_wait_timer elapsed exceeds blocking tip defers", run = test_update_inter_turn_wait_timer_elapsed_exceeds_blocking_tip_defers },
  },
}
