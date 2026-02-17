local context_builder = require("support.context_builder")
local assertions = require("support.assertions")
local time_stub = require("support.time_stub")

local function _test_auto_runner_not_advanced_when_input_blocked()
  local ctx = context_builder.new_game_context({
    ai = { [2] = true },
  })
  ctx.state.ui.input_blocked = true
  ctx.game.turn.current_player_index = 2
  ctx.game.turn.phase = "wait_action_anim"
  ctx.game.turn.turn_count = 1

  local action = nil
  time_stub.with_timestamp_stub(function()
    action = require("turn").step_auto_runner(ctx.game, ctx.state, 1.0, {
      game_finished = ctx.game.finished,
      current_player_index = ctx.game.turn.current_player_index,
      current_player_id = ctx.game.players[2].id,
      current_player_auto = true,
    })
  end)

  assertions.assert_equal(action, nil, "auto runner should not advance when input blocked")
end

return {
  layer = "regression",
  domain = "gameplay_main_flow",
  cases = {
    {
      id = "given_input_locked_when_auto_runner_step_then_no_auto_advance",
      desc = "input locked blocks auto runner",
      run = _test_auto_runner_not_advanced_when_input_blocked,
    },
  },
}
