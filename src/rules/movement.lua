local facing_policy = require("src.rules.board.facing_policy")
local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local mine_effect = require("src.rules.effects.mine")
local action_anim_port = require("src.foundation.ports.action_anim")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local movement = {}

local _emit_event = monopoly_event.emit

local function _emit_text(game, mono_kind, ef_kind, payload, opts)
  _emit_event(mono_kind, payload)
  if game and ef_kind and type(payload.text) == "string" then
    local event = { kind = ef_kind, text = payload.text }
    if not (opts and opts.show_tip == true) then
      event.tip = false
    end
    if opts and opts.tip_dedupe_key ~= nil then
      event.tip_dedupe_key = opts.tip_dedupe_key
    end
    event_feed.publish(game, event)
  end
end

local _other_action_prompt_text = "玩家正在行动"

-- context builder

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

local function _build_move_context(game, player, steps, opts)
  opts = opts or {}
  local abs_steps = steps < 0 and -steps or steps
  local ctx = _new_move_state(game, player, steps, opts, abs_steps)
  ctx.start_tile = ctx.board:get_tile(player.position)
  local start_on_outer = _resolve_start_on_outer(ctx)
  ctx.step_fn = _resolve_step_fn(ctx.board, ctx.backward)
  local facing_mode = _resolve_facing_mode(steps, opts)
  ctx.facing = facing_policy.resolve_initial_facing(facing_mode, player, opts)
  if facing_mode == "fresh_forward" then
    if facing_policy.should_skip_inner_entry(ctx.board, player) then
      ctx.skip_entry_on_tile_id = ctx.start_tile and ctx.start_tile.id or nil
      ctx.consume_skip_inner_entry = true
    end
    if ctx.entered_inner and not start_on_outer then
      ctx.facing = ctx.persisted_facing
    end
  end
  return ctx
end

-- interrupt handler

local function _check_roadblock(game, board, current, player)
  if not board:has_roadblock(current) then
    return false
  end
  local tile = board:get_tile(current)
  action_anim_port.queue(game, {
    kind = "roadblock_trigger",
    player_id = player.id,
    tile_index = current,
    duration = timing.action_anim_default_seconds or 1.0,
  })
  game:clear_roadblock(current)
  _emit_text(game, monopoly_event.movement.roadblock_hit, event_kinds.roadblock_triggered, {
    player = player,
    tile = tile,
    text = player.name .. " 触发路障，停在 " .. tile.name,
    prompt_text = _other_action_prompt_text,
  }, { show_tip = true })
  return true
end

local function _check_market(ctx, step)
  if ctx.steps <= 0 or ctx.opts.skip_market_check then
    return nil
  end
  local tile = ctx.board:get_tile(ctx.current)
  assert(tile ~= nil, "missing tile: " .. tostring(ctx.current))
  if tile.type ~= "market" or step >= ctx.steps then
    return nil
  end
  local remaining = ctx.abs_steps - step
  _emit_text(ctx.game, monopoly_event.movement.market_interrupt, event_kinds.market_entered, {
    player = ctx.player,
    remaining_steps = remaining,
    text = ctx.player.name .. " 经过黑市，剩余 " .. number_utils.format_integer_part(remaining) .. " 步",
    prompt_text = _other_action_prompt_text,
  })
  return {
    position = nil,
    remaining_steps = remaining,
    facing = ctx.facing,
    branch_parity = ctx.branch_parity,
    entered_inner = ctx.entered_inner == true,
  }
end

local function _resolve_step_interrupt(ctx, encountered_step, step)
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

local function _sync_inner_transition(ctx, entered_inner, previous_tile, current_tile)
  if entered_inner then
    ctx.entered_inner = true
    return
  end
  if previous_tile
    and current_tile
    and ctx.board.map
    and ctx.board.map.outer_next
    and ctx.board.map.outer_next[previous_tile.id] == nil
    and ctx.board.map.outer_next[current_tile.id] ~= nil then
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
  local encountered_step = {}
  for _, pid in ipairs(ctx.game.occupants[ctx.current] or {}) do
    if pid ~= ctx.player.id then
      encountered_step[#encountered_step + 1] = pid
      if pass_through then
        ctx.encountered[#ctx.encountered + 1] = pid
      end
    end
  end
  return encountered_step
end

local function _run_move_steps(ctx)
  for step = 1, ctx.abs_steps do
    _step_move(ctx, step)
    local pass_through = step < ctx.abs_steps
    local encountered_step = _collect_encountered(ctx, pass_through)
    if _resolve_step_interrupt(ctx, encountered_step, step) then
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
    market_interrupt = ctx.market_interrupt,
  }
end

-- event emitter

local function _emit_pass_start_reward(ctx)
  if ctx.pass_start <= 0 then
    return
  end
  local bonus = ctx.pass_start * constants.pass_start_bonus
  if ctx.game:player_has_deity(ctx.player, "rich") then
    bonus = bonus * 2
  end
  ctx.game:add_player_cash(ctx.player, bonus)
  local turn_count = (ctx.game and ctx.game.turn and ctx.game.turn.turn_count) or 0
  _emit_text(ctx.game, monopoly_event.movement.passed_start, event_kinds.passed_start, {
    player = ctx.player,
    count = ctx.pass_start,
    bonus = bonus,
    text = ctx.player.name .. " 经过起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
    prompt_text = _other_action_prompt_text,
  }, {
    show_tip = true,
    tip_dedupe_key = "passed_start:" .. tostring(ctx.player.id) .. ":" .. tostring(turn_count),
  })
end

local function _resolve_pass_start_hold(ctx)
  local opts = ctx.opts or {}
  if opts.pass_start_hold_seconds ~= nil then
    local override = opts.pass_start_hold_seconds
    if override < 0 then
      return 0
    end
    return override
  end
  local first_step = ctx.pass_start_at_steps[1]
  if not first_step then
    return 0
  end
  local per = timing.pass_start_hold_seconds_per_step or 0
  local hold = first_step * per
  local cap = timing.pass_start_hold_max_seconds
  if cap and hold > cap then
    hold = cap
  end
  return hold + (timing.pass_start_hold_tail_seconds or 0)
end

local function _schedule_pass_start_reward(ctx)
  if ctx.pass_start <= 0 then
    return
  end
  local hold = _resolve_pass_start_hold(ctx)
  if hold <= 0 then
    _emit_pass_start_reward(ctx)
    return
  end
  runtime_ports.schedule(hold, function()
    _emit_pass_start_reward(ctx)
  end)
end

local function _emit_move_events(ctx, landing_tile)
  _emit_text(ctx.game, monopoly_event.movement.moved, event_kinds.move_completed, {
    player = ctx.player,
    from_tile = ctx.start_tile,
    to_tile = landing_tile,
    steps = ctx.steps,
    text = ctx.player.name .. " 从 " .. ctx.start_tile.name .. " 移动到 " .. landing_tile.name,
    prompt_text = _other_action_prompt_text,
  })
  _schedule_pass_start_reward(ctx)
end

-- public API

function movement.move(game, player, steps, opts)
  local ctx = _build_move_context(game, player, steps, opts)
  _run_move_steps(ctx)
  _resolve_persisted_facing(ctx)
  local landing_tile = ctx.board:get_tile(ctx.current)
  _emit_move_events(ctx, landing_tile)
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
projectHash=d7b66e9a45ccb52c
scope.0.id=chunk:src/rules/movement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=365
scope.0.semanticHash=c392a3c5059568b9
scope.1.id=function:_emit_text:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=30
scope.1.semanticHash=d2c393c6eef46152
scope.2.id=function:_resolve_facing_mode:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=47
scope.2.semanticHash=1880056d1bddd340
scope.3.id=function:_resolve_step_fn:49
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=54
scope.3.semanticHash=0bf0cdb03e8d5219
scope.4.id=function:_new_move_state:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=81
scope.4.semanticHash=f4d2eff07c97bbc7
scope.5.id=function:_resolve_start_on_outer:83
scope.5.kind=function
scope.5.startLine=83
scope.5.endLine=92
scope.5.semanticHash=94132e1644447592
scope.6.id=function:_build_move_context:94
scope.6.kind=function
scope.6.startLine=94
scope.6.endLine=113
scope.6.semanticHash=207fa1fe0475ad10
scope.7.id=function:_check_roadblock:117
scope.7.kind=function
scope.7.startLine=117
scope.7.endLine=140
scope.7.semanticHash=7af2e4372c1f1d56
scope.8.id=function:_check_market:142
scope.8.kind=function
scope.8.startLine=142
scope.8.endLine=165
scope.8.semanticHash=bd32a4f3a3af2756
scope.9.id=function:_resolve_step_interrupt:167
scope.9.kind=function
scope.9.startLine=167
scope.9.endLine=181
scope.9.semanticHash=b31bc36323a9f46e
scope.10.id=function:_sync_inner_transition:185
scope.10.kind=function
scope.10.startLine=185
scope.10.endLine=198
scope.10.semanticHash=a786245a8bf5cfde
scope.11.id=function:_step_move:200
scope.11.kind=function
scope.11.startLine=200
scope.11.endLine=227
scope.11.semanticHash=684463d49648bbef
scope.12.id=function:_resolve_persisted_facing:255
scope.12.kind=function
scope.12.startLine=255
scope.12.endLine=259
scope.12.semanticHash=423d055c07142325
scope.13.id=function:_build_move_result:261
scope.13.kind=function
scope.13.startLine=261
scope.13.endLine=273
scope.13.semanticHash=eca24a2caa6edfde
scope.14.id=function:_emit_pass_start_reward:277
scope.14.kind=function
scope.14.startLine=277
scope.14.endLine=297
scope.14.semanticHash=cec55a7267028ade
scope.15.id=function:_resolve_pass_start_hold:299
scope.15.kind=function
scope.15.startLine=299
scope.15.endLine=319
scope.15.semanticHash=f9586e89b42f71dd
scope.16.id=function:anonymous@330:330
scope.16.kind=function
scope.16.startLine=330
scope.16.endLine=332
scope.16.semanticHash=1657e0f7425f6024
scope.17.id=function:_schedule_pass_start_reward:321
scope.17.kind=function
scope.17.startLine=321
scope.17.endLine=333
scope.17.semanticHash=8692257dd1ae0038
scope.18.id=function:_emit_move_events:335
scope.18.kind=function
scope.18.startLine=335
scope.18.endLine=345
scope.18.semanticHash=995ee3044ff4507c
scope.19.id=function:movement.move:349
scope.19.kind=function
scope.19.startLine=349
scope.19.endLine=362
scope.19.semanticHash=708235f49b7e891b
]]
