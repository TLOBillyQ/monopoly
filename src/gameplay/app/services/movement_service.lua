local constants = require("src.config.constants")
local logger = require("src.util.logger")

local MovementService = {}


local function check_mine(game, player, current_pos)
  local board = game.board
  if not board:has_mine(current_pos) then
    return false, false
  end

  if player:has_angel() then
    logger.event(player.name .. " 天使保护，地雷无效")
    board:clear_mine(current_pos)
    return true, false
  end

  board:clear_mine(current_pos)
  game:set_player_seat(player, nil)
  logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
  player:send_to_hospital(game)
  return true, true -- detonated, hospitalized
end

function MovementService.move(game, player, steps, opts)
  opts = opts or {}
  local branch_parity = opts.branch_parity or steps
  local board = game.board
  local encountered = {}
  local visited = {}
  local pass_start = 0
  local stopped_on_roadblock = false
  local current = player.position
  local start_tile = board:get_tile(current)
  local facing = opts.direction or (player.status and player.status.move_dir) or nil

  for _ = 1, steps do
    local next_index, passed, step_dir = board:step_forward_by_facing(current, facing, branch_parity)
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

    local detonated, hospitalized = check_mine(game, player, current)
    if detonated and hospitalized then
      current = player.position
      break
    end

    if board:has_roadblock(current) then
      board:clear_roadblock(current)
      stopped_on_roadblock = true
      logger.event(player.name .. " 触发路障，停在 " .. board:get_tile(current).name)
      break
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

  if game.set_player_status then
    game:set_player_status(player, "move_dir", facing)
  else
    player.status = player.status or {}
    player.status.move_dir = facing
  end

  return {
    encountered_players = encountered,
    passed_start = pass_start,
    stopped_on_roadblock = stopped_on_roadblock,
    visited = visited,
    landing_tile = landing_tile,
    steps = steps,
  }
end

return MovementService
