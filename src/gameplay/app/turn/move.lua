local function phase_move(tm, args)
  local player = args.player
  local total = args.total
  local raw_total = args.raw_total
  local movement = tm.game and tm.game.services and tm.game.services.movement
  assert(movement and movement.move, "Missing MovementService (game.services.movement)")
  local move_result = movement.move(tm.game, player, total, { branch_parity = raw_total })
  tm.game.last_turn.move_result = move_result
  return "land", { player = player, move_result = move_result }
end

return phase_move
