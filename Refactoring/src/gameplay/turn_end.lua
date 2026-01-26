local function phase_end(tm, args)
  local player = args.player
  player:tick_deity()
  player:clear_temporal_flags()
  if tm.game and tm.game.store then
    tm.game.store:set({ "turn", "market_prompt" }, nil)
    tm.game.store:set({ "turn", "post_action" }, nil)
    tm.game.store:set({ "turn", "item_phase" }, nil)
    tm.game.store:set({ "turn", "item_phase_active" }, nil)
  end
  tm:next_player()
  return nil
end

return phase_end