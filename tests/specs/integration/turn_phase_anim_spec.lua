local context_builder = require("support.context_builder")
local assertions = require("support.assertions")

local function _test_wait_move_anim_dispatches_done_with_seq()
  local dispatched = {}
  local ctx = context_builder.new_game_context({
    ports_overrides = {
      anim = {
        play_move_anim = function(_, anim_ctx)
          assertions.assert_truthy(anim_ctx and anim_ctx.seq == 7001, "move anim seq should match")
          return 0
        end,
      },
    },
  })
  ctx.state.wait_move_anim = true
  ctx.game.update = function() end
  ctx.game.dispatch_action = function(_, action)
    dispatched[#dispatched + 1] = action
  end
  ctx.game.turn.phase = "wait_move_anim"
  ctx.game.turn.move_anim = { seq = 7001 }

  context_builder.run_tick(ctx.game, ctx.state, 0.1)

  assertions.assert_truthy(dispatched[1] ~= nil, "move anim should dispatch done action")
  assertions.assert_equal(dispatched[1].type, "move_anim_done")
  assertions.assert_equal(dispatched[1].seq, 7001)
end

return {
  layer = "integration",
  domain = "turn_phase_anim",
  cases = {
    {
      id = "given_wait_move_anim_when_tick_then_dispatch_move_anim_done_with_seq",
      desc = "move anim done dispatch with seq",
      run = _test_wait_move_anim_dispatches_done_with_seq,
    },
  },
}
