local context_builder = require("src.rules.movement.context_builder")
local step_executor = require("src.rules.movement.step_executor")
local event_emitter = require("src.rules.movement.event_emitter")

local movement = {}

function movement.move(game, player, steps, opts)
  local ctx = context_builder.build(game, player, steps, opts)
  step_executor.run(ctx)
  step_executor.resolve_persisted_facing(ctx)
  local landing_tile = ctx.board:get_tile(ctx.current)
  event_emitter.emit(ctx, landing_tile)
  ctx.game:update_player_position(ctx.player, ctx.current)
  ctx.game:set_player_status(ctx.player, "move_dir", ctx.persisted_facing)
  return step_executor.build_result(ctx, landing_tile)
end

return movement
