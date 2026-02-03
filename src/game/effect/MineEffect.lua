local Logger = require("src.core.Logger")

local MineEffect = {}

function MineEffect.Apply(game, player, position)
  assert(game ~= nil, "missing game")
  local board = assert(game.board, "missing board")
  assert(player ~= nil, "missing player")
  assert(position ~= nil, "missing position")

  if player:HasAngel() then
    Logger.Event(player.name .. " 天使保护，地雷无效")
    board:ClearMine(position)
    return { detonated = true, protected = true }
  end

  board:ClearMine(position)
  if player:IsVehicleIndestructible() then
    Logger.Event(player.name .. " 座驾免疫地雷")
    return { detonated = true, protected = true }
  end
  game:SetPlayerSeat(player, nil)
  Logger.Event(player.name .. " 触发地雷，座驾被摧毁并送医")
  player:SendToHospital(game)
  return { detonated = true, hospitalized = true, new_position = player.position }
end

return MineEffect

