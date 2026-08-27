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
  -- #550:先入队 roadblock_trigger、再清 board 状态,堵死 state sync 窗口——
  -- sync_many 同拍到达时 pending 守卫(visual_sync_overlay)仍能查到 trigger,
  -- overlay 活到 trigger handler 接管,不再提前销毁。
  movement_events.emit_roadblock_hit(game, player, current, tile)
  game:clear_roadblock(current)
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

-- 出发格与到达格共用的障碍判定:路障先于地雷。
local function _check_obstacles(ctx)
  if _check_roadblock(ctx.game, ctx.board, ctx.current, ctx.player) then
    ctx.stopped_on_roadblock = true
    return true
  end
  if mine_effect.can_trigger(ctx.game, ctx.player, ctx.current) then
    return true
  end
  return false
end

local function _resolve_step_interrupt(ctx, step)
  if _check_obstacles(ctx) then
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

local function _outer_next(ctx)
  local map = ctx.board.map
  if not (map and map.outer_next) then
    return nil
  end
  return map.outer_next
end

local function _is_inner_exit_transition(ctx, previous_tile, current_tile)
  if not (previous_tile and current_tile) then
    return false
  end
  local outer_next = _outer_next(ctx)
  if outer_next == nil then
    return false
  end
  return outer_next[previous_tile.id] == nil and outer_next[current_tile.id] ~= nil
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

local function _record_passed_step(ctx, step, passed)
  if passed > 0 then
    ctx.pass_start_at_steps[#ctx.pass_start_at_steps + 1] = step
  end
end

local function _sync_arrival_direction(ctx, previous_tile, current_tile, previous_index)
  if previous_tile and current_tile and ctx.board and ctx.board.map then
    ctx.arrival_direction = ctx.board.map.direction(previous_tile.id, current_tile.id)
    ctx.arrival_from_index = previous_index
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
  _record_passed_step(ctx, step, passed)
  ctx.facing = next_facing
  local previous_tile = ctx.board:get_tile(ctx.current)
  ctx.current = next_index
  local current_tile = ctx.board:get_tile(ctx.current)
  _sync_arrival_direction(ctx, previous_tile, current_tile, previous_index)
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
  -- 出发格按到达格对待:布雷后才同格的玩家出发也必须触发,否则直接走过。
  -- 黑市不参与出发判定:恢复流与已购物的落点不能重复开市。
  if not _check_obstacles(ctx) then
    _run_move_steps(ctx)
  end
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
version=4
projectHash=52554f55e9eb5310
scope.0.id=chunk:src/rules/movement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=200
scope.0.semanticHash=60bf4ef6e98cd204
scope.1.id=function:_check_roadblock
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=20
scope.1.semanticHash=a0c296379273a383
scope.2.id=function:_check_market
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=40
scope.2.semanticHash=e0dd4756c13e46b6
scope.3.id=function:_check_obstacles
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=52
scope.3.semanticHash=dbce2d04ca3cb131
scope.4.id=function:_resolve_step_interrupt
scope.4.kind=function
scope.4.startLine=54
scope.4.endLine=64
scope.4.semanticHash=a633b00d70a92932
scope.5.id=function:_outer_next
scope.5.kind=function
scope.5.startLine=68
scope.5.endLine=74
scope.5.semanticHash=c51dfe58adc7d090
scope.6.id=function:_is_inner_exit_transition
scope.6.kind=function
scope.6.startLine=76
scope.6.endLine=85
scope.6.semanticHash=151db6d131bb9da8
scope.7.id=function:_sync_inner_transition
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=95
scope.7.semanticHash=cbfbb0c22fb690c9
scope.8.id=function:_record_passed_step
scope.8.kind=function
scope.8.startLine=97
scope.8.endLine=101
scope.8.semanticHash=c9f190f73a2611fa
scope.9.id=function:_sync_arrival_direction
scope.9.kind=function
scope.9.startLine=103
scope.9.endLine=108
scope.9.semanticHash=9ce22d287c53bed7
scope.10.id=function:_step_move
scope.10.kind=function
scope.10.startLine=110
scope.10.endLine=132
scope.10.semanticHash=9c003de9171322c4
scope.11.id=function:_collect_encountered
scope.11.kind=function
scope.11.startLine=136
scope.11.endLine=144
scope.11.semanticHash=f09b48add7beb1d1
scope.12.id=function:_run_move_steps
scope.12.kind=function
scope.12.startLine=146
scope.12.endLine=155
scope.12.semanticHash=88a53a90ecc9a387
scope.13.id=function:_resolve_persisted_facing
scope.13.kind=function
scope.13.startLine=157
scope.13.endLine=161
scope.13.semanticHash=1c02edfbf6ed6913
scope.14.id=function:_build_move_result
scope.14.kind=function
scope.14.startLine=163
scope.14.endLine=176
scope.14.semanticHash=5903f8c2c65f04e3
scope.15.id=function:movement.move
scope.15.kind=function
scope.15.startLine=180
scope.15.endLine=197
scope.15.semanticHash=32a63842006532ff
]]
