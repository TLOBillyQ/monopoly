local constants = require("Config.Generated.Constants")
local gameplay_rules = require("src.core.config.GameplayRules")
local inventory = require("src.game.systems.items.ItemInventory")
local monopoly_event = require("src.core.events.MonopolyEvents")
local number_utils = require("src.core.utils.NumberUtils")
local facing_policy = require("src.game.systems.board.FacingPolicy")

local movement = {}
local item_ids = gameplay_rules.item_ids
local _emit_event = monopoly_event.emit

local function _build_other_action_prompt_text()
  return "玩家正在行动"
end

local function _tile_label(tile)
  return tile.name
end

local function _check_roadblock(board, current, player)
  if not board:has_roadblock(current) then
    return false
  end
  board:clear_roadblock(current)
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
  }
end

function movement.move(game, player, steps, opts)
  opts = opts or {}
  local abs_steps = steps < 0 and -steps or steps
  local branch_parity = opts.branch_parity or abs_steps
  local board = game.board
  local encountered = {}
  local visited = {}
  local pass_start = 0
  local stopped_on_roadblock = false
  local market_interrupt = nil
  local steal_interrupt = nil
  local current = player.position
  local start_tile = board:get_tile(current)
  local step_fn = board.step_forward_by_facing
  local backward = steps < 0
  local facing_mode = opts.facing_mode
  if backward then
    step_fn = board.step_backward_by_facing
  end
  if not facing_mode then
    if backward then
      facing_mode = "relative_backward"
    elseif opts.direction ~= nil then
      facing_mode = "resume_forward"
    else
      facing_mode = "fresh_forward"
    end
  end
  local facing = facing_policy.resolve_initial_facing(facing_mode, player, opts)

  local mine = board.get_mine and board:get_mine(current) or nil
  if type(mine) == "table" and mine.owner_id == player.id then
    board:arm_mine(current)
  end

  for step = 1, abs_steps do
    local next_index, passed, step_dir
    if backward then
      next_index, passed, step_dir = step_fn(board, current, facing)
    else
      next_index, passed, step_dir = step_fn(board, current, facing, branch_parity)
    end
    pass_start = pass_start + passed
    facing = step_dir
    current = next_index
    visited[#visited + 1] = current

    local others = game.occupants[current] or {}
    local encountered_step = {}
    for _, pid in ipairs(others) do
      if pid ~= player.id then
        encountered_step[#encountered_step + 1] = pid
        encountered[#encountered + 1] = pid
      end
    end

    if _check_roadblock(board, current, player) then
      stopped_on_roadblock = true
      break
    end

    steal_interrupt = _check_steal(player, encountered_step, step, abs_steps, facing, branch_parity, opts)
    if steal_interrupt then
      steal_interrupt.position = current
      break
    end

    market_interrupt = _check_market(board, current, step, steps, abs_steps, facing, branch_parity, player, opts)
    if market_interrupt then
      market_interrupt.position = current
      break
    end
  end

  local landing_tile = board:get_tile(current)
  _emit_event(monopoly_event.movement.moved, {
    player = player,
    from_tile = start_tile,
    to_tile = landing_tile,
    steps = steps,
    text = player.name .. " 从 " .. _tile_label(start_tile) .. " 移动到 " .. _tile_label(landing_tile),
    prompt_text = _build_other_action_prompt_text(),
  })

  if pass_start > 0 then
    local bonus = pass_start * constants.pass_start_bonus
    game:add_player_cash(player, bonus)
    _emit_event(monopoly_event.movement.passed_start, {
      player = player,
      count = pass_start,
      bonus = bonus,
      text = player.name .. " 经过起点，获得 " .. number_utils.format_integer_part(bonus) .. " 金币",
      prompt_text = _build_other_action_prompt_text(),
    })
  end

  game:update_player_position(player, current)
  -- move_dir stores the heading used to continue movement from the current tile.
  game:set_player_status(player, "move_dir", facing)

  return {
    encountered_players = encountered,
    passed_start = pass_start,
    stopped_on_roadblock = stopped_on_roadblock,
    visited = visited,
    landing_tile = landing_tile,
    steps = steps,
    market_interrupt = market_interrupt,
    steal_interrupt = steal_interrupt,
  }
end

return movement
