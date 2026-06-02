local movement_context = require("src.rules.movement_context")
local movement_events = require("src.rules.movement_events")
local mine_effect = require("src.rules.effects.mine")

local movement = {}

-- interrupt handler

local function _check_roadblock(game, board, current, player)
  if not board:has_roadblock(current) then
    return false
  end
  local tile = board:get_tile(current)
  game:clear_roadblock(current)
  movement_events.emit_roadblock_hit(game, player, current, tile)
  return true
end

local function _check_market(ctx, step)
  if ctx.opts.skip_market_check then
    return nil
  end
  local tile = ctx.board:get_tile(ctx.current)
  assert(tile ~= nil, "missing tile: " .. tostring(ctx.current))
  if tile.type ~= "market" or step >= ctx.steps then
    return nil
  end
  local remaining = ctx.abs_steps - step
  movement_events.emit_market_interrupt(ctx, remaining)
  return {
    position = nil,
    remaining_steps = remaining,
    facing = ctx.facing,
    branch_parity = ctx.branch_parity,
    entered_inner = ctx.entered_inner == true,
  }
end

local function _resolve_step_interrupt(ctx, step)
  if _check_roadblock(ctx.game, ctx.board, ctx.current, ctx.player) then
    ctx.stopped_on_roadblock = true
    return true
  end
  if mine_effect.can_trigger(ctx.game, ctx.player, ctx.current) then
    return true
  end
  ctx.market_interrupt = _check_market(ctx, step)
  if ctx.market_interrupt then
    ctx.market_interrupt.position = ctx.current
    return true
  end
  return false
end

-- step executor

local function _is_inner_exit_transition(ctx, previous_tile, current_tile)
  if not (previous_tile and current_tile) then
    return false
  end
  local map = ctx.board.map
  if not (map and map.outer_next) then
    return false
  end
  return map.outer_next[previous_tile.id] == nil and map.outer_next[current_tile.id] ~= nil
end

local function _sync_inner_transition(ctx, entered_inner, previous_tile, current_tile)
  if entered_inner then
    ctx.entered_inner = true
    return
  end
  if _is_inner_exit_transition(ctx, previous_tile, current_tile) then
    ctx.exited_inner = true
  end
end

local function _step_move(ctx, step)
  local next_index, passed, next_facing, entered_inner
  local previous_index = ctx.current
  if ctx.backward then
    next_index, passed, next_facing = ctx.step_fn(ctx.board, ctx.current, ctx.facing)
  else
    next_index, passed, next_facing, entered_inner = ctx.step_fn(ctx.board, ctx.current, ctx.facing, {
      parity = ctx.branch_parity,
      entered_inner = ctx.entered_inner,
      skip_entry_on_tile_id = ctx.skip_entry_on_tile_id,
    })
  end
  ctx.pass_start = ctx.pass_start + passed
  if passed > 0 then
    ctx.pass_start_at_steps[#ctx.pass_start_at_steps + 1] = step
  end
  ctx.facing = next_facing
  local previous_tile = ctx.board:get_tile(ctx.current)
  ctx.current = next_index
  local current_tile = ctx.board:get_tile(ctx.current)
  if previous_tile and current_tile and ctx.board and ctx.board.map then
    ctx.arrival_direction = ctx.board.map.direction(previous_tile.id, current_tile.id)
    ctx.arrival_from_index = previous_index
  end
  _sync_inner_transition(ctx, entered_inner, previous_tile, current_tile)
  ctx.visited[#ctx.visited + 1] = ctx.current
  return step
end

-- pass_through=true: intermediate step, player is passing through.
-- pass_through=false: final step (landing tile), encounters are not "passing".
local function _collect_encountered(ctx, pass_through)
  for _, pid in ipairs(ctx.game.occupants[ctx.current] or {}) do
    if pid ~= ctx.player.id then
      if pass_through then
        ctx.encountered[#ctx.encountered + 1] = pid
      end
    end
  end
end

local function _run_move_steps(ctx)
  for step = 1, ctx.abs_steps do
    _step_move(ctx, step)
    local pass_through = step < ctx.abs_steps
    _collect_encountered(ctx, pass_through)
    if _resolve_step_interrupt(ctx, step) then
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
    arrival_direction = ctx.arrival_direction,
    arrival_from_index = ctx.arrival_from_index,
    stopped_on_roadblock = ctx.stopped_on_roadblock,
    visited = ctx.visited,
    landing_tile = landing_tile,
    steps = ctx.steps,
    branch_parity = ctx.branch_parity,
    market_interrupt = ctx.market_interrupt,
  }
end

-- public API

function movement.move(game, player, steps, opts)
  local ctx = movement_context.build(game, player, steps, opts)
  _run_move_steps(ctx)
  _resolve_persisted_facing(ctx)
  local landing_tile = ctx.board:get_tile(ctx.current)
  movement_events.emit_move_completed(ctx, landing_tile)
  ctx.game:update_player_position(ctx.player, ctx.current)
  ctx.game:set_player_status(ctx.player, "move_dir", ctx.persisted_facing)
  local should_skip_next_inner_entry = ctx.exited_inner == true
    and landing_tile ~= nil
    and ctx.board.map.entry_points[landing_tile.id] ~= nil
  ctx.game:set_player_status(ctx.player, "skip_next_inner_entry", should_skip_next_inner_entry)
  return _build_move_result(ctx, landing_tile)
end

return movement

--[[ mutate4lua-manifest
version=2
projectHash=c8de869b7eb6079c
scope.0.id=chunk:src/rules/movement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=169
scope.0.semanticHash=e291ce2fdcbc1f16
scope.0.lastMutatedAt=2026-06-02T03:23:21Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=12
scope.0.lastMutationKilled=12
scope.1.id=function:_check_roadblock:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=17
scope.1.semanticHash=7e0b056f85aee8e8
scope.1.lastMutatedAt=2026-06-02T03:23:21Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_check_market:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=37
scope.2.semanticHash=94e49538248963f1
scope.2.lastMutatedAt=2026-06-02T03:23:21Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=10
scope.2.lastMutationKilled=10
scope.3.id=function:_resolve_step_interrupt:39
scope.3.kind=function
scope.3.startLine=39
scope.3.endLine=53
scope.3.semanticHash=447dbad7c097ccad
scope.3.lastMutatedAt=2026-06-02T03:23:21Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
scope.4.id=function:_is_inner_exit_transition:57
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=66
scope.4.semanticHash=d11271cde85d8319
scope.4.lastMutatedAt=2026-06-02T03:23:21Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=9
scope.4.lastMutationKilled=9
scope.5.id=function:_sync_inner_transition:68
scope.5.kind=function
scope.5.startLine=68
scope.5.endLine=76
scope.5.semanticHash=93dab9dcfa079d62
scope.5.lastMutatedAt=2026-06-02T03:23:21Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_step_move:78
scope.6.kind=function
scope.6.startLine=78
scope.6.endLine=105
scope.6.semanticHash=684463d49648bbef
scope.6.lastMutatedAt=2026-06-02T03:23:21Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=16
scope.6.lastMutationKilled=16
scope.7.id=function:_resolve_persisted_facing:130
scope.7.kind=function
scope.7.startLine=130
scope.7.endLine=134
scope.7.semanticHash=423d055c07142325
scope.7.lastMutatedAt=2026-06-02T03:23:21Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:_build_move_result:136
scope.8.kind=function
scope.8.startLine=136
scope.8.endLine=149
scope.8.semanticHash=5697658bed53e446
scope.8.lastMutatedAt=2026-06-02T03:23:21Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=no_sites
scope.8.lastMutationSites=0
scope.8.lastMutationKilled=0
scope.9.id=function:movement.move:153
scope.9.kind=function
scope.9.startLine=153
scope.9.endLine=166
scope.9.semanticHash=488f129adb3bf6c3
scope.9.lastMutatedAt=2026-06-02T03:23:21Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=15
scope.9.lastMutationKilled=15
]]
