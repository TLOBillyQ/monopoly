local interrupt_handler = require("src.rules.movement.interrupt_handler")

local step_executor = {}

local function _step_move(ctx, step)
  local next_index, passed, next_facing, entered_inner
  if ctx.backward then
    next_index, passed, next_facing = ctx.step_fn(ctx.board, ctx.current, ctx.facing)
  else
    next_index, passed, next_facing, entered_inner = ctx.step_fn(ctx.board, ctx.current, ctx.facing, {
      parity = ctx.branch_parity,
      entered_inner = ctx.entered_inner,
    })
  end
  ctx.pass_start = ctx.pass_start + passed
  ctx.facing = next_facing
  ctx.current = next_index
  if entered_inner then
    ctx.entered_inner = true
  end
  ctx.visited[#ctx.visited + 1] = ctx.current
  return step
end

local function _collect_encountered(ctx)
  local encountered_step = {}
  for _, pid in ipairs(ctx.game.occupants[ctx.current] or {}) do
    if pid ~= ctx.player.id then
      encountered_step[#encountered_step + 1] = pid
      ctx.encountered[#ctx.encountered + 1] = pid
    end
  end
  return encountered_step
end

local function _run_move_steps(ctx)
  for step = 1, ctx.abs_steps do
    _step_move(ctx, step)
    local encountered_step = _collect_encountered(ctx)
    if interrupt_handler.resolve(ctx, encountered_step, step) then
      break
    end
  end
end

local function _resolve_persisted_facing(ctx)
  if not ctx.backward then
    ctx.persisted_facing = ctx.facing
  end
end

local function _build_move_result(ctx, landing_tile)
  return {
    encountered_players = ctx.encountered,
    passed_start = ctx.pass_start,
    stopped_on_roadblock = ctx.stopped_on_roadblock,
    visited = ctx.visited,
    landing_tile = landing_tile,
    steps = ctx.steps,
    market_interrupt = ctx.market_interrupt,
    steal_interrupt = ctx.steal_interrupt,
  }
end

step_executor.run = _run_move_steps
step_executor.resolve_persisted_facing = _resolve_persisted_facing
step_executor.build_result = _build_move_result

return step_executor
