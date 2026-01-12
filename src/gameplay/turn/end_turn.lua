local function phase_end(tm, args)
  local player = args.player
  local status = tm.game and tm.game.services and tm.game.services.status
  assert(status and status.tick_end_of_turn, "Missing StatusService (game.services.status)")
  status.tick_end_of_turn(player)
  player:clear_temporal_flags()
  tm:next_player()
  if tm.game and tm.game.commit_state then
    tm.game:commit_state()
  end
  return nil
end

return phase_end
