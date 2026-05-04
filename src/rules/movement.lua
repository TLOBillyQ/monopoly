local facing_policy = require("src.rules.board.facing_policy")
local constants = require("src.config.content.constants")
local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.lang.number")
local inventory = require("src.rules.items.inventory")
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
    event_feed.publish(game, event)
  end
end

local function _build_other_action_prompt_text()
  return "玩家正在行动"
end

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
    steal_interrupt = nil,
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
  if game:angel_immune_to_item(player, item_ids.roadblock) then
    event_feed.publish(game, {
      kind = event_kinds.item_immune,
      text = player.name .. " 有天使，路障无效（路障保留）",
    })
    return false
  end
  game:clear_roadblock(current)
  local tile = board:get_tile(current)
  action_anim_port.queue(game, {
    kind = "roadblock_trigger",
    player_id = player.id,
    tile_index = current,
    duration = timing.action_anim_default_seconds or 1.0,
  })
  _emit_text(game, monopoly_event.movement.roadblock_hit, event_kinds.roadblock_triggered, {
    player = player,
    tile = tile,
    text = player.name .. " 触发路障，停在 " .. tile.name,
    prompt_text = _build_other_action_prompt_text(),
  }, { show_tip = true })
  return true
end

local function _check_mine(game, player, current)
  return mine_effect.can_trigger(game, player, current)
end

local function _check_steal(game, player, encountered_step, step, abs_steps, facing, branch_parity, opts)
  if opts.skip_steal_check or #encountered_step == 0 then
    return nil
  end
  local has_steal = inventory.find_index(player, item_ids.steal)
  local remaining = abs_steps - step
  if not has_steal or remaining <= 0 then
    return nil
  end
  _emit_text(game, monopoly_event.movement.steal_interrupt, event_kinds.steal, {
    player = player,
    encountered_ids = encountered_step,
    text = player.name .. " 经过玩家，触发偷窃中断",
    prompt_text = _build_other_action_prompt_text(),
  })
  return {
    position = nil,
    remaining_steps = remaining,
    facing = facing,
    branch_parity = branch_parity,
    entered_inner = opts.entered_inner == true,
    encountered_ids = encountered_step,
  }
end

local function _check_market(game, board, current, step, steps, abs_steps, facing, branch_parity, player, opts)
  if steps <= 0 or opts.skip_market_check then
    return nil
  end
  local tile = board:get_tile(current)
  assert(tile ~= nil, "missing tile: " .. tostring(current))
  if tile.type ~= "market" or step >= steps then
    return nil
  end
  local remaining = abs_steps - step
  _emit_text(game, monopoly_event.movement.market_interrupt, event_kinds.market_entered, {
    player = player,
    remaining_steps = remaining,
    text = player.name .. " 经过黑市，剩余 " .. number_utils.format_integer_part(remaining) .. " 步",
    prompt_text = _build_other_action_prompt_text(),
  })
  return {
    position = nil,
    remaining_steps = remaining,
    facing = facing,
    branch_parity = branch_parity,
    entered_inner = opts.entered_inner == true,
  }
end

local function _resolve_step_interrupt(ctx, encountered_step, step)
  if _check_roadblock(ctx.game, ctx.board, ctx.current, ctx.player) then
    ctx.stopped_on_roadblock = true
    return true
  end
  if _check_mine(ctx.game, ctx.player, ctx.current) then
    return true
  end
  ctx.steal_interrupt = _check_steal(
    ctx.game,
    ctx.player,
    encountered_step,
    step,
    ctx.abs_steps,
    ctx.facing,
    ctx.branch_parity,
    {
      skip_steal_check = ctx.opts.skip_steal_check,
      entered_inner = ctx.entered_inner,
    }
  )
  if ctx.steal_interrupt then
    ctx.steal_interrupt.position = ctx.current
    return true
  end
  ctx.market_interrupt = _check_market(
    ctx.game,
    ctx.board,
    ctx.current,
    step,
    ctx.steps,
    ctx.abs_steps,
    ctx.facing,
    ctx.branch_parity,
    ctx.player,
    {
      skip_market_check = ctx.opts.skip_market_check,
      entered_inner = ctx.entered_inner,
    }
  )
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
    steal_interrupt = ctx.steal_interrupt,
  }
end

-- event emitter

local function _tile_label(tile)
  return tile.name
end

local function _emit_pass_start_reward(ctx)
  if ctx.pass_start <= 0 then
    return
  end
  local bonus = ctx.pass_start * constants.pass_start_bonus
  ctx.game:add_player_cash(ctx.player, bonus)
  _emit_text(ctx.game, monopoly_event.movement.passed_start, event_kinds.passed_start, {
    player = ctx.player,
    count = ctx.pass_start,
    bonus = bonus,
    text = ctx.player.name .. " 经过起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
    prompt_text = _build_other_action_prompt_text(),
  }, { show_tip = true })
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
    return cap
  end
  return hold
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
    text = ctx.player.name .. " 从 " .. _tile_label(ctx.start_tile) .. " 移动到 " .. _tile_label(landing_tile),
    prompt_text = _build_other_action_prompt_text(),
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
