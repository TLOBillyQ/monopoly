local constants = require("src.config.constants")
local logger = require("src.util.logger")

local MovementService = {}

function MovementService.move(game, player, steps, opts)
  opts = opts or {}
  local abs_steps = math.abs(steps or 0)
  local branch_parity = opts.branch_parity or abs_steps
  local board = game.board
  local encountered = {}
  local visited = {}
  local pass_start = 0
  local stopped_on_roadblock = false
  local market_interrupt = nil
  local current = player.position
  local start_tile = board:get_tile(current)
  local facing = opts.direction or (player.status and player.status.move_dir) or nil
  local step_fn = (steps or 0) < 0 and board.step_backward_by_facing or board.step_forward_by_facing

  for step = 1, abs_steps do
    local next_index, passed, step_dir = step_fn(board, current, facing, branch_parity)
    pass_start = pass_start + passed
    facing = step_dir or facing
    current = next_index
    table.insert(visited, current)

    local others = game.occupants[current] or {}
    for _, pid in ipairs(others) do
      if pid ~= player.id then
        table.insert(encountered, pid)
      end
    end

    if board:has_roadblock(current) then
      board:clear_roadblock(current)
      stopped_on_roadblock = true
      logger.event(player.name .. " 触发路障，停在 " .. board:get_tile(current).name)
      break
    end

    -- 经过黑市时中断（非最后一步），skip_market_check 用于测试
    if steps > 0 and not opts.skip_market_check then
      local tile = board:get_tile(current)
      if tile and tile.type == "market" and step < steps then
        market_interrupt = {
          position = current,
          remaining_steps = abs_steps - step,
          facing = facing,
          branch_parity = branch_parity,
        }
        logger.event(player.name .. " 经过黑市，剩余 " .. market_interrupt.remaining_steps .. " 步")
        break
      end
    end
  end

  local landing_tile = board:get_tile(current)
  logger.event(player.name .. " 从 " .. (start_tile and start_tile.name or tostring(player.position)) .. " 移动到 " .. (landing_tile and landing_tile.name or tostring(current)))

  if pass_start > 0 then
    local bonus = pass_start * constants.pass_start_bonus
    player:add_cash(bonus)
    logger.event(player.name .. " 经过起点，获得 " .. bonus .. " 金币")
  end

  game:update_player_position(player, current)

  game:set_player_status(player, "move_dir", facing)

  return {
    encountered_players = encountered,
    passed_start = pass_start,
    stopped_on_roadblock = stopped_on_roadblock,
    visited = visited,
    landing_tile = landing_tile,
    steps = steps,
    market_interrupt = market_interrupt,
  }
end

return MovementService
