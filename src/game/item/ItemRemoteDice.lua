local logger = require("src.core.Logger")

local remote_dice = {}

function remote_dice.apply(game, player, dice_count, value)
  assert(dice_count ~= nil and dice_count >= 1, "invalid dice_count")
  local values = {}
  for i = 1, dice_count do
    values[i] = value
  end
  game:set_player_status(player, "pending_remote_dice", { values = values })
  logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

return remote_dice

