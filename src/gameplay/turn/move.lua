local MovementService = require("src.gameplay.services.movement_service")

local function phase_move(tm, args)
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total
  local move_result = MovementService.move(tm.game, player, total, { branch_parity = raw_total })
  tm.game.last_turn.move_result = move_result
  return "land", { player = player, move_result = move_result }
end

return phase_move
