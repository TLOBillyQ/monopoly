local constants = require("src.config.constants")
local logger = require("src.util.logger")

local MovementService = {}


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
  local tile_service = game and game.services and game.services.tile

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

    if tile_service and tile_service.check_mine then
      local detonated, hospitalized = tile_service.check_mine(game, player, current)
      if detonated and hospitalized then
        current = player.position
        break
      end
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
