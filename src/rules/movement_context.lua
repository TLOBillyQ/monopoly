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

local function _start_tile_id(ctx)
  return ctx.start_tile and ctx.start_tile.id or nil
end

local function _apply_fresh_forward_entry_policy(ctx, start_on_outer)
  if facing_policy.should_skip_inner_entry(ctx.board, ctx.player) then
    ctx.skip_entry_on_tile_id = _start_tile_id(ctx)
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
version=4
projectHash=97d1f87dee5ef343
scope.0.id=chunk:src/rules/movement_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=93
scope.0.semanticHash=6ef18b04e2d7aa79
scope.1.id=function:_resolve_facing_mode
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=16
scope.1.semanticHash=dfc46a8bb80b0edb
scope.2.id=function:_resolve_step_fn
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=23
scope.2.semanticHash=04a6b4497c6c1286
scope.3.id=function:_new_move_state
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=50
scope.3.semanticHash=e3c1e881928ed3ae
scope.4.id=function:_resolve_start_on_outer
scope.4.kind=function
scope.4.startLine=52
scope.4.endLine=61
scope.4.semanticHash=16712419be41de57
scope.5.id=function:_start_tile_id
scope.5.kind=function
scope.5.startLine=63
scope.5.endLine=65
scope.5.semanticHash=13ddff47d34fa2ed
scope.6.id=function:_apply_fresh_forward_entry_policy
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=75
scope.6.semanticHash=147d597891ae68e0
scope.7.id=function:context.build
scope.7.kind=function
scope.7.startLine=77
scope.7.endLine=90
scope.7.semanticHash=efc2f7dabb6081a5
]]
