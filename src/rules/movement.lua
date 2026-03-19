local constants = require("src.config.content.constants")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local inventory = require("src.rules.items.inventory")
local monopoly_event = require("src.core.events.monopoly_events")
local number_utils = require("src.core.utils.number_utils")
local facing_policy = require("src.rules.board.facing_policy")

local movement = {}
local item_ids = gameplay_rules.item_ids
local _emit_event = monopoly_event.emit

local function _build_other_action_prompt_text()
  return "玩家正在行动"
end

local function _tile_label(tile)
  return tile.name
end

local function _check_roadblock(game, board, current, player)
  if not board:has_roadblock(current) then
    return false
  end
  game:clear_roadblock(current)
  _emit_event(monopoly_event.movement.roadblock_hit, {
    player = player,
    tile = board:get_tile(current),
    text = player.name .. " 触发路障，停在 " .. board:get_tile(current).name,
    prompt_text = _build_other_action_prompt_text(),
  })
  return true
end

local function _check_steal(player, encountered_step, step, abs_steps, facing, branch_parity, opts)
  if opts.skip_steal_check or #encountered_step == 0 then
    return nil
  end
  local has_steal = inventory.find_index(player, item_ids.steal)
  local remaining = abs_steps - step
  if not has_steal or remaining <= 0 then
    return nil
  end
  _emit_event(monopoly_event.movement.steal_interrupt, {
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

local function _check_market(board, current, step, steps, abs_steps, facing, branch_parity, player, opts)
  if steps <= 0 or opts.skip_market_check then
    return nil
  end
  local tile = board:get_tile(current)
  assert(tile ~= nil, "missing tile: " .. tostring(current))
  if tile.type ~= "market" or step >= steps then
    return nil
  end
  local remaining = abs_steps - step
  _emit_event(monopoly_event.movement.market_interrupt, {
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
    stopped_on_roadblock = false,
    market_interrupt = nil,
    steal_interrupt = nil,
    current = player.position,
    backward = backward,
    entered_inner = opts.entered_inner == true,
    persisted_facing = player.status and player.status.move_dir or nil,
  }
end

local function _build_move_context(game, player, steps, opts)
  opts = opts or {}
  local abs_steps = steps < 0 and -steps or steps
  local ctx = _new_move_state(game, player, steps, opts, abs_steps)
  ctx.start_tile = ctx.board:get_tile(player.position)
  local start_on_outer = false
  if ctx.start_tile and ctx.board.map and ctx.board.map.outer_next then
    start_on_outer = ctx.board.map.outer_next[ctx.start_tile.id] ~= nil
    if not start_on_outer then
      ctx.entered_inner = true
    end
  end
  ctx.step_fn = _resolve_step_fn(ctx.board, ctx.backward)
  local facing_mode = _resolve_facing_mode(steps, opts)
  ctx.facing = facing_policy.resolve_initial_facing(facing_mode, player, opts)
  if facing_mode == "fresh_forward" and ctx.entered_inner and not start_on_outer then
    ctx.facing = ctx.persisted_facing
  end
  return ctx
end

local function _arm_owned_mine(ctx)
  local mine = ctx.board.get_mine and ctx.board:get_mine(ctx.current) or nil
  if type(mine) == "table" and mine.owner_id == ctx.player.id then
    ctx.board:arm_mine(ctx.current)
  end
end

local function _step_move(ctx, step)
  local next_index, passed, step_dir, entered_inner
  if ctx.backward then
    next_index, passed, step_dir = ctx.step_fn(ctx.board, ctx.current, ctx.facing)
  else
    next_index, passed, step_dir, entered_inner = ctx.step_fn(ctx.board, ctx.current, ctx.facing, {
      parity = ctx.branch_parity,
      entered_inner = ctx.entered_inner,
    })
  end
  ctx.pass_start = ctx.pass_start + passed
  ctx.facing = step_dir
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

local function _resolve_step_interrupt(ctx, encountered_step, step)
  if _check_roadblock(ctx.game, ctx.board, ctx.current, ctx.player) then
    ctx.stopped_on_roadblock = true
    return true
  end
  ctx.steal_interrupt = _check_steal(
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

local function _emit_move_events(ctx, landing_tile)
  _emit_event(monopoly_event.movement.moved, {
    player = ctx.player,
    from_tile = ctx.start_tile,
    to_tile = landing_tile,
    steps = ctx.steps,
    text = ctx.player.name .. " 从 " .. _tile_label(ctx.start_tile) .. " 移动到 " .. _tile_label(landing_tile),
    prompt_text = _build_other_action_prompt_text(),
  })
  if ctx.pass_start <= 0 then
    return
  end
  local bonus = ctx.pass_start * constants.pass_start_bonus
  ctx.game:add_player_cash(ctx.player, bonus)
  _emit_event(monopoly_event.movement.passed_start, {
    player = ctx.player,
    count = ctx.pass_start,
    bonus = bonus,
    text = ctx.player.name .. " 经过起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
    prompt_text = _build_other_action_prompt_text(),
  })
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

function movement.move(game, player, steps, opts)
  local ctx = _build_move_context(game, player, steps, opts)
  _arm_owned_mine(ctx)
  _run_move_steps(ctx)
  _resolve_persisted_facing(ctx)
  local landing_tile = ctx.board:get_tile(ctx.current)
  _emit_move_events(ctx, landing_tile)
  ctx.game:update_player_position(ctx.player, ctx.current)
  ctx.game:set_player_status(ctx.player, "move_dir", ctx.persisted_facing)
  return _build_move_result(ctx, landing_tile)
end

return movement
