local context_builder = require("support.context_builder")
local assertions = require("support.assertions")

local function _test_input_lock_follows_phase_within_ticks()
  local ctx = context_builder.new_game_context({})
  ctx.game.update = function() end

  ctx.game.turn.phase = "wait_action_anim"
  context_builder.run_tick(ctx.game, ctx.state, 0.1)
  assertions.assert_equal(ctx.state.ui.input_blocked, true, "wait_action_anim should lock input")

  ctx.game.turn.phase = "start"
  context_builder.run_tick(ctx.game, ctx.state, 0.1)
  assertions.assert_equal(ctx.state.ui.input_blocked, false, "start phase should unlock input")
end

return {
  layer = "integration",
  domain = "visual_input_lock",
  cases = {
    {
      id = "given_phase_changes_when_tick_then_input_blocked_follows_phase",
      desc = "input lock follows phase transitions",
      run = _test_input_lock_follows_phase_within_ticks,
    },
  },
}
