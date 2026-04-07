local item_ids = require("src.config.gameplay.item_ids")
local timing = require("src.config.gameplay.timing")
local inventory = require("src.rules.items.inventory")
local monopoly_event = require("src.core.events")
local number_utils = require("src.core.utils.number_utils")
local mine_effect = require("src.rules.effects.mine")
local action_anim_port = require("src.core.ports.action_anim")

local interrupt_handler = {}
local _emit_event = monopoly_event.emit

local function _build_other_action_prompt_text()
  return "玩家正在行动"
end

local function _check_roadblock(game, board, current, player)
  if not board:has_roadblock(current) then
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
  _emit_event(monopoly_event.movement.roadblock_hit, {
    player = player,
    tile = tile,
    text = player.name .. " 触发路障，停在 " .. tile.name,
    prompt_text = _build_other_action_prompt_text(),
  })
  return true
end

local function _check_mine(game, player, current)
  return mine_effect.can_trigger(game, player, current)
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

local function _resolve_step_interrupt(ctx, encountered_step, step)
  if _check_roadblock(ctx.game, ctx.board, ctx.current, ctx.player) then
    ctx.stopped_on_roadblock = true
    return true
  end
  if _check_mine(ctx.game, ctx.player, ctx.current) then
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

interrupt_handler.resolve = _resolve_step_interrupt

return interrupt_handler
