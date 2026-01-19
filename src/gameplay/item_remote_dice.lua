local logger = require("src.util.logger")

local RemoteDice = {}

function RemoteDice.apply(game, player, dice_count, value)
  if not dice_count or dice_count < 1 then
    return false
  end
  local values = {}
  for i = 1, dice_count do
    values[i] = value
  end
  game:set_player_status(player, "pending_remote_dice", { values = values })
  logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

return RemoteDice