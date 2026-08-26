local lu = require("luaunit")
local support = require("test.support.shared_support")
local afk_signal = require("src.turn.policies.afk_signal")
local action_button_timer = require("src.turn.policies.action_button_timer")
local tick_choice_timeout = require("test.support.choice_timeout")
local target_select_timer = require("src.turn.waits.target_select_timer")
local pending_confirmation = require("src.state.pending_confirmation")
local runtime_state = require("src.state.runtime")
local deadlines = require("src.turn.deadlines")
local gameplay_loop = require("src.turn.loop.init")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local control = require("src.player.control")

local function _player(id)
  local player = { id = id or 7, name = "P7", eliminated = false }
  control.initialize(player)
  return player
end

local function _game(player, choice)
  local game = {
    finished = false,
    players = { player },
    turn = {
      current_player_index = 1,
      pending_choice = choice,
      phase = "wait_action",
    },
  }
  function game:find_player_by_id(role_id)
    if role_id == player.id then
      return player
    end
    return nil
  end
  function game:current_player()
    return player
  end
  return game
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

TestAfkWiring = {}

function TestAfkWiring:test_action_button_timeout_emits_the_action_button_signal()
  local player = _player()
  local game = _game(player)
  local state = { action_button_player_id = player.id, action_button_elapsed = 15 }
  local calls = {}

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function(_, state_arg, role_id, window_kind)
        calls[#calls + 1] = { state = state_arg, role_id = role_id, window_kind = window_kind }
      end,
    },
  }, function()
    action_button_timer.update_action_button_timer({
      state = state,
      game = game,
      dt = 0,
      ports = { ui_sync = {} },
      dispatch_next = function() end,
    })
  end)

  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1].state, state)
  lu.assertEquals(calls[1].role_id, player.id)
  lu.assertEquals(calls[1].window_kind, "action_button")
end

function TestAfkWiring:test_choice_timeout_emits_owner_signal_and_marks_timeout_input()
  local choice = { id = 1, kind = "market_buy", route_key = "market", owner_role_id = 7 }
  local player = _player()
  local game = _game(player, choice)
  local output = _choice_output(choice, 1)
  local state = { gameplay_loop_ports = { output = output.ports } }
  local calls = {}
  local dispatched = {}

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function(_, state_arg, role_id, window_kind)
        calls[#calls + 1] = { state = state_arg, role_id = role_id, window_kind = window_kind }
      end,
    },
  }, function()
    tick_choice_timeout.new({
      on_pending_choice = function() end,
      is_choice_active = function() return true end,
      build_action = function() return { type = "choice_cancel", input_source = "user" } end,
      dispatch_action_with_close_choice = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
      get_timeout_seconds = function() return 1 end,
      get_min_visible_seconds = function() return 100 end,
    }).step(game, state, 0)
  end)

  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1].state, state)
  lu.assertEquals(calls[1].role_id, player.id)
  lu.assertEquals(calls[1].window_kind, "market_buy")
  lu.assertEquals(#dispatched, 1)
  lu.assertEquals(dispatched[1].input_source, "timeout")
end

function TestAfkWiring:test_choice_timeout_does_not_emit_a_signal_for_an_auto_owner()
  local choice = { id = 3, kind = "choice", route_key = "r", owner_role_id = 7 }
  local player = _player()
  control.toggle_manual_delegation(player)
  local game = _game(player, choice)
  local output = _choice_output(choice, 1)
  local state = { gameplay_loop_ports = { output = output.ports } }
  local calls = 0

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
  }, function()
    tick_choice_timeout.new({
      on_pending_choice = function() end,
      is_choice_active = function() return true end,
      build_action = function() return { type = "choice_cancel" } end,
      dispatch_action_with_close_choice = function() end,
      get_timeout_seconds = function() return 1 end,
      get_min_visible_seconds = function() return 100 end,
    }).step(game, state, 0)
  end)

  lu.assertEquals(calls, 0)
end

function TestAfkWiring:test_choice_timeout_uses_the_choice_owner_not_the_current_turn_player()
  local owner = _player(7)
  local current = _player(8)
  local choice = { id = 6, kind = "choice", route_key = "r", owner_role_id = owner.id }
  local game = {
    finished = false,
    players = { current, owner },
    turn = {
      current_player_index = 1,
      pending_choice = choice,
      phase = "wait_choice",
    },
  }
  function game:find_player_by_id(role_id)
    for _, player in ipairs(self.players) do
      if player.id == role_id then
        return player
      end
    end
    return nil
  end
  function game:current_player()
    return current
  end

  local output = _choice_output(choice, 1)
  local state = { gameplay_loop_ports = { output = output.ports } }
  local calls = {}

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function(_, state_arg, role_id, window_kind)
        calls[#calls + 1] = {
          state = state_arg,
          role_id = role_id,
          window_kind = window_kind,
        }
      end,
    },
  }, function()
    tick_choice_timeout.new({
      on_pending_choice = function() end,
      is_choice_active = function() return true end,
      build_action = function() return { type = "choice_cancel" } end,
      dispatch_action_with_close_choice = function() end,
      get_timeout_seconds = function() return 1 end,
      get_min_visible_seconds = function() return 100 end,
    }).step(game, state, 0)
  end)

  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1].state, state)
  lu.assertEquals(calls[1].role_id, owner.id)
  lu.assertEquals(calls[1].window_kind, "choice")
end

function TestAfkWiring:test_target_select_timeout_emits_the_target_owner_signal()
  local choice = { id = 2, kind = "item_target_tile", owner_role_id = 7 }
  local player = _player()
  local game = _game(player, choice)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = {}
  local resolved = false

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function(_, state_arg, role_id, window_kind)
        calls[#calls + 1] = { state = state_arg, role_id = role_id, window_kind = window_kind }
      end,
    },
    {
      target = deadlines,
      key = "resolve_target_select",
      value = function() resolved = true end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    deadlines.tick(state, 16)
  end)

  lu.assertTrue(resolved)
  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1].state, state)
  lu.assertEquals(calls[1].role_id, player.id)
  lu.assertEquals(calls[1].window_kind, "target_select")
end

function TestAfkWiring:test_target_select_timeout_does_not_signal_a_dangling_owner()
  local choice = { id = 4, kind = "item_target_tile", owner_role_id = 99 }
  local player = _player()
  local game = _game(player, choice)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = 0
  local resolved = false

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
    {
      target = deadlines,
      key = "resolve_target_select",
      value = function() resolved = true end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    deadlines.tick(state, 16)
  end)

  lu.assertTrue(resolved)
  lu.assertEquals(calls, 0)
end

function TestAfkWiring:test_target_select_timeout_ignores_a_choice_cleared_before_deadline()
  local choice = { id = 5, kind = "item_target_tile", owner_role_id = 7 }
  local player = _player()
  local game = _game(player, choice)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = 0
  local resolved = false

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
    {
      target = deadlines,
      key = "resolve_target_select",
      value = function() resolved = true end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    game.turn.pending_choice = nil
    deadlines.tick(state, 16)
  end)

  lu.assertEquals(calls, 0)
  lu.assertFalse(resolved)
end

function TestAfkWiring:test_target_select_does_not_arm_when_a_turn_exists_without_a_choice()
  local player = _player()
  local game = _game(player, nil)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = 0
  local resolved = false

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
    {
      target = deadlines,
      key = "resolve_target_select",
      value = function() resolved = true end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    lu.assertFalse(deadlines.is_active(state, "target_select"))
    deadlines.tick(state, 16)
  end)

  lu.assertEquals(calls, 0)
  lu.assertFalse(resolved)
end

function TestAfkWiring:test_target_select_replaces_a_deadline_armed_for_a_previous_choice()
  local player = _player()
  local first_choice = { id = 8, kind = "item_target_tile", owner_role_id = 7 }
  local second_choice = { id = 9, kind = "item_target_tile", owner_role_id = 7 }
  local game = _game(player, first_choice)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = 0

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    lu.assertTrue(deadlines.is_active(state, "target_select"))
    game.turn.pending_choice = second_choice
    target_select_timer.step(game, state, 0)
    lu.assertTrue(deadlines.is_active(state, "target_select"))
    deadlines.tick(state, 16)
  end)

  lu.assertEquals(calls, 1)
end

function TestAfkWiring:test_target_select_timeout_ignores_a_pending_choice_that_changed_before_deadline()
  local player = _player()
  local armed_choice = { id = 10, kind = "item_target_tile", owner_role_id = 7 }
  local other_choice = { id = 11, kind = "item_target_tile", owner_role_id = 7 }
  local game = _game(player, armed_choice)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = 0
  local resolved = false

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
    {
      target = deadlines,
      key = "resolve_target_select",
      value = function() resolved = true end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    game.turn.pending_choice = other_choice
    deadlines.tick(state, 16)
  end)

  lu.assertEquals(calls, 0)
  lu.assertFalse(resolved)
end

function TestAfkWiring:test_target_select_and_choice_timeout_same_frame_signal_once_and_advance_once()
  local choice = { id = 7, kind = "item_target_tile", owner_role_id = 7 }
  local player = _player()
  local game = _game(player, choice)
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local calls = 0
  local advances = 0
  game.advance_turn = function()
    advances = advances + 1
  end

  support.with_patches({
    {
      target = afk_signal,
      key = "on_timeout_fallback",
      value = function() calls = calls + 1 end,
    },
  }, function()
    target_select_timer.step(game, state, 0)
    deadlines.tick(state, 16)
    target_select_timer.step(game, state, 0)
    tick_choice_timeout.new({
      on_pending_choice = function() end,
      is_choice_active = function() return false end,
      build_action = function() return nil end,
      dispatch_action_with_close_choice = function() end,
      get_timeout_seconds = function() return 1 end,
      get_min_visible_seconds = function() return 100 end,
    }).step(game, state, 16)
  end)

  lu.assertEquals(calls, 1)
  lu.assertEquals(advances, 1)
  lu.assertNil(game.turn.pending_choice)
end

function TestAfkWiring:test_auto_runner_shows_the_recovery_hint_only_for_afk_source()
  local player = _player()
  control.enable_afk_delegation(player)
  local game = _game(player)
  local tips = {}
  local dispatched = {}
  game.tip_output_port = {
    enqueue = function(_, maybe_game, maybe_intent)
      tips[#tips + 1] = maybe_intent or maybe_game
      return true
    end,
  }
  local state = {
    auto_runner = {
      next_action = function()
        return { type = "ui_button", id = "next", actor_role_id = player.id }
      end,
    },
  }

  support.with_patches({
    {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
    },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0, {
      current_player_id = player.id,
      current_player_computer_controlled = true,
    })
  end)

  lu.assertEquals(#tips, 1)
  lu.assertEquals(tips[1].role_id, player.id)
  lu.assertEquals(tips[1].text, "你正在托管中，点击托管按钮恢复")
  lu.assertEquals(tips[1].source, "afk.auto_runner")
  lu.assertEquals(#dispatched, 1)

  control.toggle_manual_delegation(player)
  control.toggle_manual_delegation(player)
  tips = {}
  support.with_patches({
    {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function() end,
    },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0, {
      current_player_id = player.id,
      current_player_computer_controlled = true,
    })
  end)
  lu.assertEquals(#tips, 0)
end

function TestAfkWiring:test_auto_runner_emits_a_recovery_hint_for_each_actual_auto_action()
  local player = _player()
  control.enable_afk_delegation(player)
  local game = _game(player)
  local tips = {}
  local dispatched = {}
  game.tip_output_port = {
    enqueue = function(_, maybe_game, maybe_intent)
      tips[#tips + 1] = maybe_intent or maybe_game
      return true
    end,
  }
  local state = {
    auto_runner = {
      next_action = function()
        return { type = "ui_button", id = "next", actor_role_id = player.id }
      end,
    },
  }

  support.with_patches({
    {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function(_, _, action)
        dispatched[#dispatched + 1] = action
      end,
    },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0, {
      current_player_id = player.id,
      current_player_computer_controlled = true,
    })
    gameplay_loop.step_auto_runner(game, state, 0, {
      current_player_id = player.id,
      current_player_computer_controlled = true,
    })
  end)

  lu.assertEquals(#dispatched, 2)
  lu.assertEquals(#tips, 2)
  lu.assertEquals(tips[1].role_id, player.id)
  lu.assertEquals(tips[2].role_id, player.id)
  lu.assertEquals(tips[1].text, "你正在托管中，点击托管按钮恢复")
  lu.assertEquals(tips[2].text, "你正在托管中，点击托管按钮恢复")
end

function TestAfkWiring:test_auto_runner_hint_goes_only_to_the_afk_seat()
  local afk_player = _player(7)
  control.enable_afk_delegation(afk_player)
  local other_player = _player(8)
  local game = _game(afk_player)
  game.players = { afk_player, other_player }
  function game:find_player_by_id(role_id)
    for _, player in ipairs(self.players) do
      if player.id == role_id then
        return player
      end
    end
    return nil
  end
  local tips = {}
  game.tip_output_port = {
    enqueue = function(_, intent)
      tips[#tips + 1] = intent
      return true
    end,
  }
  local state = {
    auto_runner = {
      next_action = function()
        return { type = "ui_button", id = "next", actor_role_id = afk_player.id }
      end,
    },
  }

  support.with_patches({
    {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function() end,
    },
  }, function()
    gameplay_loop.step_auto_runner(game, state, 0, {
      current_player_id = afk_player.id,
      current_player_computer_controlled = true,
    })
  end)

  lu.assertEquals(#tips, 1)
  lu.assertEquals(tips[1].role_id, afk_player.id)
  lu.assertNotEquals(tips[1].role_id, other_player.id)
end

function TestAfkWiring:test_auto_runner_does_not_hint_ai_or_unknown_source_auto_actions()
  local cases = {
    { name = "ai", mutate = function(player)
      player.is_ai = true
      control.initialize(player)
    end },
    { name = "manual_delegation", mutate = function(player)
      control.toggle_manual_delegation(player)
    end },
  }

  for _, case in ipairs(cases) do
    local player = _player()
    case.mutate(player)
    local game = _game(player)
    local tips = {}
    game.tip_output_port = {
      enqueue = function(_, intent)
        tips[#tips + 1] = intent
        return true
      end,
    }
    local state = {
      auto_runner = {
        next_action = function()
          return { type = "ui_button", id = "next", actor_role_id = player.id }
        end,
      },
    }

    support.with_patches({
      {
        target = turn_dispatch,
        key = "dispatch_action",
        value = function() end,
      },
    }, function()
      gameplay_loop.step_auto_runner(game, state, 0, {
        current_player_id = player.id,
        current_player_computer_controlled = true,
      })
    end)

    lu.assertEquals(#tips, 0, case.name .. " auto action must not receive the AFK hint")
  end
end

function TestAfkWiring:test_auto_runner_does_not_hint_when_no_auto_action_is_generated()
  local player = _player()
  control.enable_afk_delegation(player)
  local game = _game(player)
  local tips = {}
  game.tip_output_port = {
    enqueue = function(_, intent)
      tips[#tips + 1] = intent
      return true
    end,
  }
  local state = {
    auto_runner = {
      next_action = function() return nil end,
    },
  }

  support.with_patches({
    {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function() error("no action should be dispatched") end,
    },
  }, function()
    local action = gameplay_loop.step_auto_runner(game, state, 0, {
      current_player_id = player.id,
      current_player_computer_controlled = true,
    })
    lu.assertNil(action)
  end)

  lu.assertEquals(#tips, 0)
end

return TestAfkWiring
