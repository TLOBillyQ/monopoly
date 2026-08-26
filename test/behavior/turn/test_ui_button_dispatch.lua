local lu = require("luaunit")
local action_dispatcher = require("src.turn.actions.action_dispatcher")

TestUiButtonDispatch = {}

local function _state()
  return {
    gameplay_loop_ports = {
      output = {
        invalidate_ui_model = function() end,
      },
      ui_sync = {
        get_ui_state = function() return nil end,
        resolve_ui_gate = function() return nil end,
      },
      clock = {
        wall_now_seconds = function() return 0 end,
        wall_diff_seconds = function(a, b) return a - b end,
      },
    },
  }
end

local function _game()
  local player = { id = 1 }
  local game = {
    turn = { phase = "wait_action", current_player_index = 1 },
    players = { player },
    dispatched = {},
  }
  function game:dispatch_action(action)
    self.dispatched[#self.dispatched + 1] = action
  end
  return game
end

function TestUiButtonDispatch:test_next_routes_through_game_dispatch_action()
  local game = _game()
  local action = { type = "ui_button", id = "next", actor_role_id = 1 }

  local result = action_dispatcher.dispatch_action(game, _state(), action)

  lu.assertEquals(result, { status = "applied" })
  lu.assertEquals(game.dispatched, { action })
end

function TestUiButtonDispatch:test_unknown_button_is_rejected()
  local result = action_dispatcher.dispatch_action(_game(), _state(), {
    type = "ui_button",
    id = "unknown",
    actor_role_id = 1,
  })

  lu.assertEquals(result, { status = "rejected" })
end

function TestUiButtonDispatch:test_cancel_redispatches_the_current_cancelable_choice()
  local game = _game()
  game.turn.pending_choice = { id = "choice-1", allow_cancel = true }

  local result = action_dispatcher.dispatch_action(game, _state(), {
    type = "ui_button",
    id = "cancel",
    actor_role_id = 1,
  })

  lu.assertEquals(result, { status = "applied" })
  lu.assertEquals(game.dispatched[1].type, "choice_cancel")
  lu.assertEquals(game.dispatched[1].choice_id, "choice-1")
end

function TestUiButtonDispatch:test_cancel_rejects_missing_or_non_cancelable_choices()
  local game = _game()
  local action = { type = "ui_button", id = "cancel", actor_role_id = 1 }

  lu.assertEquals(action_dispatcher.dispatch_action(game, _state(), action), { status = "rejected" })
  game.turn.pending_choice = { id = "choice-2", allow_cancel = false }
  lu.assertEquals(action_dispatcher.dispatch_action(game, _state(), action), { status = "rejected" })
end

function TestUiButtonDispatch:test_step_turn_requires_game()
  local ok, err = pcall(action_dispatcher.step_turn, nil)

  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "missing game")
end

function TestUiButtonDispatch:test_dispatch_action_requires_action()
  local ok, err = pcall(action_dispatcher.dispatch_action, {}, _state(), nil)

  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "missing action")
end

return TestUiButtonDispatch
