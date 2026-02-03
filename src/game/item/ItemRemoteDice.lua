local Logger = require("src.core.Logger")

local RemoteDice = {}

function RemoteDice.Apply(game, player, dice_count, value)
  assert(dice_count ~= nil and dice_count >= 1, "invalid dice_count")
  local values = {}
  for i = 1, dice_count do
    values[i] = value
  end
  game:SetPlayerStatus(player, "pending_remote_dice", { values = values })
  Logger.Event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

return RemoteDice

