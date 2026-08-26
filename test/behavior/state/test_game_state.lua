local lu = require("luaunit")
local Game = require("src.state.game_state")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local _config_reset = require("test.support.config_reset")

TestGameState = {}

function TestGameState:setUp()
  _config_reset.reset_all()
end

function TestGameState:test_constructor_does_not_install_runtime_ports()
  local g = Game:new({})

  lu.assertNil(g.anim_gate_port)
  lu.assertNil(g.popup_port)
  lu.assertNil(g.tip_output_port)
  lu.assertNil(g.tile_feedback_port)
  lu.assertNil(g.board_visual_feedback_port)
  lu.assertNil(g.bankruptcy_feedback_port)
end

function TestGameState:test_advance_turn_returns_early_when_finished()
  local g = Game:new({})
  g.finished = true
  local called = false
  g.turn_runtime = { run_turn = function() called = true end }
  g:advance_turn()
  _assert_eq(called, false, "advance_turn should return early when finished=true")
end

function TestGameState:test_dispatch_action_returns_early_when_finished()
  local g = Game:new({})
  g.finished = true
  local called = false
  g.turn_runtime = { dispatch = function() called = true end }
  g:dispatch_action({ type = "test" })
  _assert_eq(called, false, "dispatch_action should return early when finished=true")
end

function TestGameState:test_advance_turn_skips_silently_without_runtime()
  local g = Game:new({})
  local victory_calls = 0
  g.check_victory = function() victory_calls = victory_calls + 1 end
  g:advance_turn()
  _assert_eq(victory_calls, 1, "advance_turn without runtime should still check victory")
end

function TestGameState:test_turn_facades_delegate_before_checking_victory()
  local g = Game:new({})
  local calls = {}
  local action = { type = "test" }
  g.turn_runtime = {
    run_turn = function()
      calls[#calls + 1] = "run_turn"
    end,
    dispatch = function(_, received_action)
      _assert_eq(received_action, action, "dispatch should receive the original action")
      calls[#calls + 1] = "dispatch"
    end,
  }
  g.check_victory = function()
    calls[#calls + 1] = "check_victory"
  end

  g:advance_turn()
  g:dispatch_action(action)

  lu.assertEquals(calls, { "run_turn", "check_victory", "dispatch", "check_victory" })
end

function TestGameState:test_dispatch_action_skips_silently_without_runtime()
  local g = Game:new({})
  local victory_calls = 0
  g.check_victory = function() victory_calls = victory_calls + 1 end
  g:dispatch_action({ type = "test" })
  _assert_eq(victory_calls, 1, "dispatch_action without runtime should still check victory")
end

function TestGameState:test_rebuild_excludes_eliminated_players_and_starts_at_one()
  local g = Game:new({})
  g.board = { length = function() return 3 end }
  g.players = {
    { id = 1, position = 2, eliminated = false },
    { id = 2, position = 2, eliminated = true },
    { id = 3, position = 3, eliminated = false },
  }
  g:rebuild()
  _assert_eq(#g.occupants, 3, "occupants should span board length")
  lu.assertEvalToTrue(g.occupants[0] == nil, "occupants should not have a 0 slot")
  lu.assertEvalToTrue(g.occupants[2][1] == 1, "alive player should occupy slot 2")
  lu.assertEvalToTrue(g.occupants[2][2] == nil, "eliminated player should not occupy slot 2")
  lu.assertEvalToTrue(g.occupants[3][1] == 3, "alive player should occupy slot 3")
end


return TestGameState
