local lu = require("luaunit")
local support = require("test.support.shared_support")
local fixtures = require("test.support.gameplay_fixtures")
local afk_signal = require("src.turn.policies.afk_signal")
local action_button_timer = require("src.turn.policies.action_button_timer")
local tick_choice_timeout = require("test.support.choice_timeout")
local target_select_timer = require("src.turn.waits.target_select_timer")
local pending_confirmation = require("src.state.pending_confirmation")
local runtime_state = require("src.state.runtime")
local deadlines = require("src.turn.deadlines")
local gameplay_loop = require("src.turn.loop.init")
local ChoiceTimeout = require("src.turn.waits.choice_timeout")
local modal_timeout = require("src.turn.waits.modal_timeout")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local timing = require("src.config.gameplay.timing")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_log = require("src.state.event_log")
local logger = require("src.foundation.log")
local test_env = require("test.support.env")
local control = require("src.player.control")

local function _new_game()
  return support.new_game({ players = { "P1", "P2" }, ai = {} })
end

local function _build_tick_state()
  local state = fixtures.build_loop_state()
  state.auto_runner.interval = 0.01
  state.gameplay_loop_ports.ui_sync.step_choice_timeout = function(game, state_arg, dt)
    return ChoiceTimeout.step_default(game, state_arg, dt)
  end
  state.gameplay_loop_ports.ui_sync.step_modal_timeout = function(game, state_arg, dt)
    return modal_timeout.step_default(game, state_arg, dt)
  end
  state._resolved_gameplay_loop_ports = nil
  return state
end

local function _prepare_wait_action(game, state)
  game.turn.phase = "wait_action"
  game.turn.current_player_index = 1
  game.turn.pending_choice = nil
  state.ui.choice_active = false
  state.ui.popup_active = false
  state.ui.input_blocked = false
end

local function _afk_count(state, role_id)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  return turn_runtime.afk_timeout_counts[role_id]
end

local function _tick(game, state, dt, on_dispatch)
  local game_api = GameAPI or {}
  local now = 0
  local patches = {
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      now = now + 1
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
    { target = logger, key = "info", value = function() end },
    { target = logger, key = "info_unlimited", value = function() end },
    { target = logger, key = "warn", value = function() end },
  }
  if on_dispatch then
    patches[#patches + 1] = {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function(_, _, action)
        on_dispatch(action)
        return true
      end,
    }
  end
  support.with_patches(patches, function()
    gameplay_loop.tick(game, state, dt)
  end)
end

local function _capture_tips(game)
  local tips = {}
  game.tip_output_port.enqueue = function(_, intent)
    tips[#tips + 1] = intent
    return true
  end
  return tips
end

local function _choice_output(choice, elapsed)
  local output = {
    pending_choice = choice,
    pending_choice_id = choice.id,
    pending_choice_elapsed = elapsed or 0,
  }
  output.ports = {
    get_pending_choice = function() return output.pending_choice end,
    sync_pending_choice = function(_, value)
      output.pending_choice = value
      output.pending_choice_id = value and value.id or nil
      output.pending_choice_elapsed = 0
    end,
    clear_pending_choice = function()
      output.pending_choice = nil
      output.pending_choice_id = nil
      output.pending_choice_elapsed = 0
    end,
    get_pending_choice_id = function() return output.pending_choice_id end,
    set_pending_choice_id = function(_, value) output.pending_choice_id = value end,
    get_pending_choice_elapsed = function() return output.pending_choice_elapsed end,
    set_pending_choice_elapsed = function(_, value) output.pending_choice_elapsed = value end,
  }
  return output
end

TestAfkLifecycle = {}

-- mutate 内建 runner 不加载 test/helper.lua，没有 per-case reseed 兜底；
-- 本类用例走完整 tick 链会消费全局 RNG，入例必须显式重播默认种子，
-- 否则单进程全量跑时序列位置随此前用例消耗漂移（见 test_rng_reset_isolation）。
function TestAfkLifecycle:setUp()
  test_env.reseed_defaults()
end

function TestAfkLifecycle:test_prune_tolerates_a_missing_state()
  lu.assertNil(afk_signal.prune(_new_game(), nil))
end

function TestAfkLifecycle:test_tick_clears_a_partial_count_when_eliminated_during_the_tick()
  local game = _new_game()
  local state = _build_tick_state()
  local player = game.players[1]

  afk_signal.reset(state)
  lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
  lu.assertEquals(_afk_count(state, player.id), 1)

  state.auto_runner.next_action = function()
    game.players[1].eliminated = true
    return nil
  end
  gameplay_loop.tick(game, state, 0)

  lu.assertNil(_afk_count(state, player.id), "elimination during a tick must clear the seat count immediately")
end

function TestAfkLifecycle:test_tick_clears_all_counts_once_the_game_finishes_during_the_tick()
  local game = _new_game()
  local state = _build_tick_state()
  local player = game.players[1]

  afk_signal.reset(state)
  lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
  lu.assertEquals(_afk_count(state, player.id), 1)

  state.auto_runner.next_action = function()
    game.finished = true
    return nil
  end
  gameplay_loop.tick(game, state, 1)

  lu.assertNil(_afk_count(state, player.id), "game finish during a tick must clear AFK detection state")
end

function TestAfkLifecycle:test_residual_choice_timeout_for_an_eliminated_owner_never_signals_afk()
  local player = { id = 7, name = "P7", is_ai = false, eliminated = true }
  control.initialize(player)
  local choice = { id = 1, kind = "choice", route_key = "r", owner_role_id = player.id }
  local game = {
    finished = false,
    players = { player },
    turn = { current_player_index = 1, pending_choice = choice, phase = "wait_choice" },
  }
  function game:find_player_by_id(role_id)
    if role_id == player.id then return player end
    return nil
  end
  local output = _choice_output(choice, 1)
  local state = { gameplay_loop_ports = { output = output.ports } }
  local calls = 0
  local resolved = 0

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
    {
      target = deadlines,
      key = "force_skip",
      value = function() resolved = resolved + 1 end,
    },
  }, function()
    tick_choice_timeout.new({
      on_pending_choice = function() end,
      is_choice_active = function() return true end,
      build_action = function() return { type = "choice_force_skip" } end,
      dispatch_action_with_close_choice = function() end,
      get_timeout_seconds = function() return 1 end,
      get_min_visible_seconds = function() return 100 end,
    }).step(game, state, 0)
  end)

  lu.assertEquals(calls, 0, "an eliminated choice owner must never emit an AFK timeout signal")
  lu.assertEquals(resolved, 1, "the residual choice must still be force-skipped through the existing safety net")
end

function TestAfkLifecycle:test_finished_game_tick_cancels_stale_wait_deadlines_after_finish()
  local game = _new_game()
  local state = _build_tick_state()
  local deadline_fired = false

  deadlines.start(state, "target_select", {
    timeout_seconds = 1,
    priority = 80,
    on_timeout = function()
      deadline_fired = true
    end,
  })
  lu.assertTrue(deadlines.is_active(state, "target_select"))

  state.auto_runner.next_action = function()
    game.finished = true
    return nil
  end
  gameplay_loop.tick(game, state, 0)

  lu.assertFalse(deadlines.is_active(state, "target_select"), "finishing the game must cancel residual wait deadlines")
  deadlines.tick(state, 2)
  lu.assertFalse(deadline_fired, "a cancelled deadline must not fire after the game has finished")
end

function TestAfkLifecycle:test_post_finish_timeout_input_and_auto_runner_never_emit_afk_effects()
  local auto_runner = require("src.turn.policies.auto_runner")
  local event_feed = require("src.rules.ports.event_feed")
  local tips = 0
  local player = { id = 7, name = "P7" }
  control.initialize(player)
  control.enable_afk_delegation(player)
  local game = {
    finished = true,
    players = { player },
    tip_output_port = {
      enqueue = function()
        tips = tips + 1
        return true
      end,
    },
  }
  function game:find_player_by_id(role_id)
    if role_id == player.id then return player end
    return nil
  end
  local published = 0
  local logs = 0
  local state = {
    auto_runner = auto_runner:new({ interval = 0 }),
  }
  state.auto_runner:set_enabled(true)
  afk_signal.reset(state)

  support.with_patches({
    { target = event_feed, key = "publish", value = function() published = published + 1 end },
    { target = logger, key = "info_unlimited", value = function() logs = logs + 1 end },
  }, function()
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "action_button"))
    lu.assertFalse(afk_signal.on_timeout_fallback(game, state, player.id, "choice"))
    afk_signal.on_real_input(game, state, player.id)
    lu.assertNil(gameplay_loop.step_auto_runner(game, state, 1, {
      current_player_id = player.id,
      current_player_computer_controlled = true,
    }))
  end)

  lu.assertTrue(control.is_afk_delegated(player))
  lu.assertEquals(published, 0, "post-finish timeout or input must not publish AFK placement")
  lu.assertEquals(logs, 0, "post-finish timeout or input must not write AFK placement logs")
  lu.assertEquals(tips, 0, "post-finish AutoRunner must not emit the private recovery hint")
end

function TestAfkLifecycle:test_finished_game_tick_never_revives_an_afk_timeout_count()
  local game = _new_game()
  local state = _build_tick_state()
  local player = game.players[1]

  game.finished = true
  state.action_button_active = true
  state.action_button_elapsed = 99
  state.action_button_player_id = player.id
  _prepare_wait_action(game, state)

  _tick(game, state, 1)

  lu.assertNil(_afk_count(state, player.id), "a finished-game tick must not count an action-button timeout")
  lu.assertFalse(control.is_delegated(player))
  lu.assertFalse(control.is_afk_delegated(player))
end

function TestAfkLifecycle:test_set_game_clears_afk_progress_action_timer_and_stale_wait_deadlines_for_the_same_role()
  local old_game = _new_game()
  local state = _build_tick_state()
  local old_player = old_game.players[1]
  local deadline_fired = false

  gameplay_loop.set_game(state, old_game)
  lu.assertFalse(afk_signal.on_timeout_fallback(old_game, state, old_player.id, "action_button"))
  state.action_button_active = true
  state.action_button_elapsed = 99
  state.action_button_player_id = old_player.id
  state._target_select_deadline_choice_id = 44
  state._target_select_timeout_choice_id = 44
  deadlines.start(state, "target_select", {
    timeout_seconds = 1,
    priority = 80,
    on_timeout = function()
      deadline_fired = true
    end,
  })
  lu.assertTrue(deadlines.is_active(state, "target_select"))

  local new_game = _new_game()
  gameplay_loop.set_game(state, new_game)

  lu.assertNil(_afk_count(state, old_player.id), "same role_id must not inherit the previous game's AFK progress")
  lu.assertEquals(state.action_button_elapsed, 0)
  lu.assertFalse(state.action_button_active)
  lu.assertNil(state.action_button_player_id)
  lu.assertNil(state._target_select_deadline_choice_id)
  lu.assertNil(state._target_select_timeout_choice_id)
  lu.assertFalse(deadlines.is_active(state, "target_select"), "set_game must cancel the previous game's wait deadlines")

  deadlines.tick(state, 2)
  lu.assertFalse(deadline_fired, "a cancelled old-game deadline must never fire in the new game")
end

function TestAfkLifecycle:test_first_tick_of_a_new_game_does_not_count_same_role_stale_action_elapsed()
  local old_game = _new_game()
  local state = _build_tick_state()
  local old_player = old_game.players[1]

  gameplay_loop.set_game(state, old_game)
  lu.assertFalse(afk_signal.on_timeout_fallback(old_game, state, old_player.id, "action_button"))
  state.action_button_active = true
  state.action_button_elapsed = 99
  state.action_button_player_id = old_player.id

  local new_game = _new_game()
  gameplay_loop.set_game(state, new_game)
  _prepare_wait_action(new_game, state)

  _tick(new_game, state, 0.1)

  lu.assertNil(_afk_count(state, old_player.id), "the new game's first tick must not inherit the same role's timeout elapsed")
  lu.assertFalse(control.is_delegated(new_game.players[1]))
  lu.assertFalse(control.is_afk_delegated(new_game.players[1]))
end

function TestAfkLifecycle:test_ai_never_signals_for_action_button_choice_or_target_select_timeouts()
  local ai = { id = 9, name = "AI", is_ai = true }
  control.initialize(ai)
  local choice = { id = 2, kind = "choice", route_key = "r", owner_role_id = ai.id }
  local game = {
    finished = false,
    players = { ai },
    turn = { current_player_index = 1, pending_choice = choice, phase = "wait_choice" },
  }
  function game:find_player_by_id(role_id)
    if role_id == ai.id then return ai end
    return nil
  end
  function game:current_player() return ai end
  local calls = 0

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
  }, function()
    action_button_timer.update_action_button_timer({
      state = { action_button_player_id = ai.id, action_button_elapsed = 15 },
      game = game,
      dt = 0,
      ports = { ui_sync = {} },
      dispatch_next = function() end,
    })

    local output = _choice_output(choice, 1)
    local choice_state = { gameplay_loop_ports = { output = output.ports } }
    tick_choice_timeout.new({
      on_pending_choice = function() end,
      is_choice_active = function() return true end,
      build_action = function() return { type = "choice_force_skip" } end,
      dispatch_action_with_close_choice = function() end,
      get_timeout_seconds = function() return 1 end,
      get_min_visible_seconds = function() return 100 end,
    }).step(game, choice_state, 0)

    local target_state = {}
    runtime_state.ensure_all(target_state)
    pending_confirmation.enter(target_state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
    target_select_timer.step(game, target_state, 0)
    deadlines.tick(target_state, 16)
  end)

  lu.assertEquals(calls, 0, "AI seats must be exempt from every AFK timeout signal")
  lu.assertFalse(control.is_delegated(ai))
  lu.assertFalse(control.is_afk_delegated(ai))
end

function TestAfkLifecycle:test_timeout_placement_waits_for_the_next_auto_runner_interval_before_takeover()
  local game = _new_game()
  local state = _build_tick_state()
  state.auto_runner.interval = 0.5
  local player = game.players[1]
  local dispatched = {}

  _prepare_wait_action(game, state)
  gameplay_loop.set_game(state, game)
  local tips = _capture_tips(game)

  _tick(game, state, 15.1, function(action)
    dispatched[#dispatched + 1] = action
  end)
  lu.assertEquals(#dispatched, 1, "the first timeout dispatches exactly one fallback action")
  lu.assertFalse(control.is_delegated(player))
  lu.assertEquals(_afk_count(state, player.id), 1)

  _tick(game, state, 15.1, function(action)
    dispatched[#dispatched + 1] = action
  end)
  lu.assertEquals(#dispatched, 2, "the AFK-placement timeout tick must not also auto-answer in the same tick")
  lu.assertTrue(control.is_delegated(player))
  lu.assertTrue(control.is_afk_delegated(player))
  lu.assertNil(_afk_count(state, player.id))
  lu.assertEquals(#tips, 1)
  lu.assertEquals(tips[1].text, "P1 已进入托管")
  lu.assertNil(tips[1].role_id)
  lu.assertEquals(tips[1].source, "afk")

  _tick(game, state, 0.1, function(action)
    dispatched[#dispatched + 1] = action
  end)
  lu.assertEquals(#dispatched, 2, "AutoRunner must keep its interval and not answer before it elapses")

  _tick(game, state, 0.5, function(action)
    dispatched[#dispatched + 1] = action
  end)
  lu.assertEquals(#dispatched, 3, "AutoRunner takes over on the first normal tick after its interval")
  lu.assertEquals(#tips, 2)
  lu.assertEquals(tips[2].role_id, player.id)
  lu.assertEquals(tips[2].source, "afk.auto_runner")
  lu.assertEquals(tips[2].text, "你正在托管中，点击托管按钮恢复")

  local tips_before_restore = #tips
  local result = turn_dispatch.dispatch_action(game, state, {
    type = "ui_button",
    id = "auto",
    actor_role_id = player.id,
  })
  lu.assertEquals(result.status, "applied")
  lu.assertFalse(control.is_delegated(player))
  lu.assertFalse(control.is_afk_delegated(player))
  lu.assertEquals(#tips, tips_before_restore, "manual recovery must stay silent")
end

function TestAfkLifecycle:test_all_human_seats_afk_still_finish_with_the_existing_auto_runner_and_endgame_semantics()
  local game = _new_game()
  local state = _build_tick_state()

  _prepare_wait_action(game, state)
  gameplay_loop.set_game(state, game)
  local tips = _capture_tips(game)

  support.with_patches({
    { target = timing, key = "turn_limit", value = 6 },
    { target = timing, key = "auto_decision_delay_seconds", value = 0 },
  }, function()
    _tick(game, state, 15.1)
    _tick(game, state, 15.1)
    lu.assertTrue(control.is_afk_delegated(game.players[1]))

    _tick(game, state, 15.1)
    _tick(game, state, 15.1)
    lu.assertTrue(control.is_afk_delegated(game.players[2]))

    local ticks = 0
    while not game.finished and ticks < 400 do
      _tick(game, state, 0.02)
      ticks = ticks + 1
    end
    lu.assertTrue(game.finished, "all-human AFK must still reach game.finished through the existing safety nets")
  end)

  lu.assertEquals(game.winner_names, "P1、P2", "turn-limit tie must keep the existing winner semantics")
  lu.assertEquals(#game.winners, 2)
  lu.assertNil(game.winner)

  local global_tips = 0
  for _, tip in ipairs(tips) do
    if tip.source == "afk" then
      global_tips = global_tips + 1
    end
  end
  lu.assertEquals(global_tips, 2, "each AFK placement broadcasts exactly once")

  local afk_entries = 0
  for _, entry in ipairs(event_log.get_entries(game.state.event_log)) do
    if entry.kind == event_kinds.afk_auto_enabled then
      afk_entries = afk_entries + 1
    end
  end
  lu.assertEquals(afk_entries, 2, "the event log must contain exactly one AFK placement per human seat")

  local tips_after_finish = #tips
  local entries_after_finish = afk_entries
  _tick(game, state, 0.1)
  _tick(game, state, 0.1)
  lu.assertEquals(#tips, tips_after_finish, "post-finish ticks must not produce AFK broadcasts or recovery hints")
  local final_afk_entries = 0
  for _, entry in ipairs(event_log.get_entries(game.state.event_log)) do
    if entry.kind == event_kinds.afk_auto_enabled then
      final_afk_entries = final_afk_entries + 1
    end
  end
  lu.assertEquals(final_afk_entries, entries_after_finish, "post-finish ticks must not duplicate AFK placement events")
end

return TestAfkLifecycle
