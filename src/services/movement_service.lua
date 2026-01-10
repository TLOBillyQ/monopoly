local constants = require("src.config.constants")
local logger = require("src.services.logger")

local MovementService = {}

function MovementService.move(game, player, steps)
  local board = game.board
  local encountered = {}
  local visited = {}
  local pass_start = 0
  local stopped_on_roadblock = false
  local current = player.position
  local parity = steps -- 用总点数决定分支

  for _ = 1, steps do
    local next_index, passed = board:advance(current, 1, parity)
    pass_start = pass_start + passed
    current = next_index
    table.insert(visited, current)

    local others = game.occupants[current] or {}
    for _, pid in ipairs(others) do
      if pid ~= player.id then
        table.insert(encountered, pid)
      end
    end

    if game.overlays.roadblocks[current] then
      game.overlays.roadblocks[current] = nil
      stopped_on_roadblock = true
      logger.event(player.name .. " 触发路障，停在 " .. board:get_tile(current).name)
      break
    end
  end

  if pass_start > 0 then
    local bonus = pass_start * constants.pass_start_bonus
    player:add_cash(bonus)
    logger.event(player.name .. " 经过起点，获得 " .. bonus .. " 金币")
  end

  game:update_player_position(player, current)

  local landing_tile = board:get_tile(current)
  if landing_tile.type == "start" then
    player:add_cash(constants.pass_start_bonus)
    logger.event(player.name .. " 停在起点，获得 " .. constants.pass_start_bonus .. " 金币")
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
