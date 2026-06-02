local facing_policy = require("src.rules.board.facing_policy")

local context = {}

local function _resolve_facing_mode(steps, opts)
  if opts.facing_mode then
    return opts.facing_mode
  end
  if steps < 0 then
    return "relative_backward"
  end
  if opts.direction ~= nil then
    return "resume_forward"
  end
  return "fresh_forward"
end

local function _resolve_step_fn(board, backward)
  if backward then
    return board.step_backward_by_facing
  end
  return board.step_forward_by_facing
end

local function _new_move_state(game, player, steps, opts, abs_steps)
  local backward = steps < 0
  return {
    game = game,
    player = player,
    steps = steps,
    abs_steps = abs_steps,
    opts = opts,
    board = game.board,
    branch_parity = opts.branch_parity or abs_steps,
    encountered = {},
    visited = {},
    pass_start = 0,
    pass_start_at_steps = {},
    stopped_on_roadblock = false,
    market_interrupt = nil,
    current = player.position,
    backward = backward,
    entered_inner = opts.entered_inner == true,
    skip_entry_on_tile_id = nil,
    consume_skip_inner_entry = false,
    exited_inner = false,
    -- move_dir stores the next forward heading from the player's landing tile.
    persisted_facing = player.status and player.status.move_dir or nil,
  }
end

local function _resolve_start_on_outer(ctx)
  if not (ctx.start_tile and ctx.board.map and ctx.board.map.outer_next) then
    return false
  end
  local start_on_outer = ctx.board.map.outer_next[ctx.start_tile.id] ~= nil
  if not start_on_outer then
    ctx.entered_inner = true
  end
  return start_on_outer
end

local function _apply_fresh_forward_entry_policy(ctx, start_on_outer)
  if facing_policy.should_skip_inner_entry(ctx.board, ctx.player) then
    ctx.skip_entry_on_tile_id = ctx.start_tile and ctx.start_tile.id or nil
    ctx.consume_skip_inner_entry = true
  end
  if ctx.entered_inner and not start_on_outer then
    ctx.facing = ctx.persisted_facing
  end
end

function context.build(game, player, steps, opts)
  opts = opts or {}
  local abs_steps = math.abs(steps)
  local ctx = _new_move_state(game, player, steps, opts, abs_steps)
  ctx.start_tile = ctx.board:get_tile(player.position)
  local start_on_outer = _resolve_start_on_outer(ctx)
  ctx.step_fn = _resolve_step_fn(ctx.board, ctx.backward)
  local facing_mode = _resolve_facing_mode(steps, opts)
  ctx.facing = facing_policy.resolve_initial_facing(facing_mode, player, opts)
  if facing_mode == "fresh_forward" then
    _apply_fresh_forward_entry_policy(ctx, start_on_outer)
  end
  return ctx
end

return context

--[[ mutate4lua-manifest
version=2
projectHash=26c2cab353e277d3
scope.0.id=chunk:src/rules/movement_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=89
scope.0.semanticHash=b455c5c668946796
scope.0.lastMutatedAt=2026-06-02T03:12:11Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:_resolve_facing_mode:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=16
scope.1.semanticHash=1880056d1bddd340
scope.1.lastMutatedAt=2026-06-02T03:12:11Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_resolve_step_fn:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=0bf0cdb03e8d5219
scope.3.id=function:_new_move_state:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=50
scope.3.semanticHash=f4d2eff07c97bbc7
scope.3.lastMutatedAt=2026-06-02T03:12:11Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:_resolve_start_on_outer:52
scope.4.kind=function
scope.4.startLine=52
scope.4.endLine=61
scope.4.semanticHash=94132e1644447592
scope.4.lastMutatedAt=2026-06-02T03:12:11Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:_apply_fresh_forward_entry_policy:63
scope.5.kind=function
scope.5.startLine=63
scope.5.endLine=71
scope.5.semanticHash=951891738380793f
scope.5.lastMutatedAt=2026-06-02T03:12:11Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:context.build:73
scope.6.kind=function
scope.6.startLine=73
scope.6.endLine=86
scope.6.semanticHash=7e07f88a320bc20e
scope.6.lastMutatedAt=2026-06-02T03:12:11Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=11
scope.6.lastMutationKilled=11
]]
