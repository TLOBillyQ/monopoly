local logger = require("src.util.logger")

local MineEffect = {}

function MineEffect.apply(game, player, position)
  local board = game.board
  if not player or not position then
    return { detonated = false }
  end

  if player:has_angel() then
    logger.event(player.name .. " 天使保护，地雷无效")
    board:clear_mine(position)
    return { detonated = true, protected = true }
  end

  board:clear_mine(position)
  if player:is_vehicle_indestructible() then
    logger.event(player.name .. " 座驾免疫地雷")
    return { detonated = true, protected = true }
  end
  game:set_player_seat(player, nil)
  logger.event(player.name .. " 触发地雷，座驾被摧毁并送医")
  player:send_to_hospital(game)
  return { detonated = true, hospitalized = true, new_position = player.position }
end

return MineEffect