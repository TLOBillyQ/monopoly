local lu = require("luaunit")
local support = require("test.support.shared_support")

local action_button_timer = require("src.turn.policies.action_button_timer")
local control = require("src.player.control")
local constants = require("src.config.content.constants")

-- 原生 LuaUnit 迁移:三个同级 describe 无钩子,合并为单个 Test* 类,用例数与
-- 改写前一一对应(12 例)。

-- Build a ctx that drives update_action_button_timer down the tracking path:
-- ports.ui_sync is present but inert so is_action_button_wait_active returns true,
-- and the current player resolves from turn.current_player_index.
local function _timer_ctx(opts)
  opts = opts or {}
  local player = opts.player or { id = 1 }
  local state = opts.state or {}
  local dispatched = {}
  local game = {
    finished = false,
    turn = {
      current_player_index = 1,
      phase = opts.phase,
      pending_choice = nil,
    },
    players = { player },
    auto_play_port = opts.auto_play_port,
  }
  local ctx = {
    state = state,
    game = game,
    dt = opts.dt or 0,
    ports = { ui_sync = {} },
    dispatch_next = function(id, reason)
      dispatched[#dispatched + 1] = { id = id, reason = reason }
    end,
  }
  return ctx, state, game, dispatched
end

TestActionButtonTimerSurvivors = {}

function TestActionButtonTimerSurvivors:test_treats_a_nil_elapsed_as_zero()
  lu.assertIs(action_button_timer.resolve_elapsed(nil, 3), 3)
end

function TestActionButtonTimerSurvivors:test_treats_a_nil_dt_as_zero()
  lu.assertIs(action_button_timer.resolve_elapsed(2, nil), 2)
end

function TestActionButtonTimerSurvivors:test_keeps_tracking_a_manually_delegated_player_outside_wait_action()
  -- 托管真人由统一玩家控制查询裁决;非 wait_action 阶段仍保持追踪。
  local player = { id = 1 }
  control.initialize(player)
  control.toggle_manual_delegation(player)
  local ctx, state = _timer_ctx({ phase = "idle", player = player })

  action_button_timer.update_action_button_timer(ctx)

  lu.assertTrue(state.action_button_active)
end

function TestActionButtonTimerSurvivors:test_keeps_tracking_a_replacement_computer_outside_wait_action()
  local player = { id = 1, is_ai = true }
  control.initialize(player)
  local ctx, state = _timer_ctx({ phase = "idle", player = player })

  action_button_timer.update_action_button_timer(ctx)

  lu.assertTrue(state.action_button_active)
end

function TestActionButtonTimerSurvivors:test_does_not_track_a_direct_player_outside_wait_action()
  -- 直接操作真人只在 wait_action 阶段被追踪;非 wait_action 阶段必须停止。
  local player = { id = 1 }
  control.initialize(player)
  local ctx, state = _timer_ctx({ phase = "idle", player = player })

  action_button_timer.update_action_button_timer(ctx)

  lu.assertEvalToFalse(state.action_button_active)
end

function TestActionButtonTimerSurvivors:test_resets_the_elapsed_timer_and_re_owns_the_button_on_a_player_switch()
  local ctx, state = _timer_ctx({ phase = "wait_action", dt = 0 })
  state.action_button_player_id = 999
  state.action_button_elapsed = 10

  action_button_timer.update_action_button_timer(ctx)

  lu.assertIs(state.action_button_player_id, 1)
  lu.assertIs(state.action_button_elapsed, 0)
  lu.assertTrue(state.action_button_active)
end

TestActionButtonTimerSurvivors["test_stays_within_the_window_without_firing_a_timeout_while_elapsed < timeout"] = function(self)
  local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 1 })

  action_button_timer.update_action_button_timer(ctx)

  lu.assertIs(#dispatched, 0)
  lu.assertIs(state.action_button_elapsed, 1)
end

function TestActionButtonTimerSurvivors:test_fires_a_timeout_once_elapsed_reaches_the_timeout_boundary()
  local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 0 })
  state.action_button_player_id = 1
  state.action_button_elapsed = 15

  action_button_timer.update_action_button_timer(ctx)

  lu.assertIs(#dispatched, 1)
  lu.assertIs(dispatched[1].reason, "timeout")
end

function TestActionButtonTimerSurvivors:test_clears_the_elapsed_timer_when_a_timeout_is_handled()
  local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 0 })
  state.action_button_player_id = 1
  state.action_button_elapsed = 20

  action_button_timer.update_action_button_timer(ctx)

  lu.assertIs(#dispatched, 1)
  lu.assertIs(state.action_button_elapsed, 0)
end

function TestActionButtonTimerSurvivors:test_stays_inert_when_the_configured_timeout_is_unset()
  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = false },
  }, function()
    local ctx, state = _timer_ctx({ phase = "wait_action", dt = 0 })

    action_button_timer.update_action_button_timer(ctx)

    lu.assertFalse(state.action_button_active)
  end)
end

function TestActionButtonTimerSurvivors:test_stays_inert_when_the_configured_timeout_is_zero()
  support.with_patches({
    { target = constants, key = "action_timeout_seconds", value = 0 },
  }, function()
    local ctx, state, _, dispatched = _timer_ctx({ phase = "wait_action", dt = 0 })

    action_button_timer.update_action_button_timer(ctx)

    lu.assertIs(#dispatched, 0)
    lu.assertFalse(state.action_button_active)
  end)
end


function TestActionButtonTimerSurvivors:test_stays_inert_when_context_state_is_missing()
  action_button_timer.update_action_button_timer(nil)
  action_button_timer.update_action_button_timer({})
  lu.assertEvalToTrue(true, "update_action_button_timer should tolerate a missing context state")
end


return TestActionButtonTimerSurvivors
