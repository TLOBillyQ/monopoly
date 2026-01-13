local function phase_end(tm, args)
  local player = args.player
  local status = tm.game and tm.game.services and tm.game.services.status
  assert(status and status.tick_end_of_turn, "Missing StatusService (game.services.status)")
  status.tick_end_of_turn(player)
  player:clear_temporal_flags()
  if tm.game and tm.game.store then
    tm.game.store:set({ "turn", "market_prompt" }, nil)
    tm.game.store:set({ "turn", "post_action" }, nil)
  end
  tm:next_player()
  return nil
end

return phase_end
