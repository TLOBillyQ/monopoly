local function _PhaseEnd(tm, args)
  local player = args.player
  player:tick_deity()
  player:clear_temporal_flags()
  assert(tm.game ~= nil and tm.game.store ~= nil, "missing game/store")
  tm.game.store:set({ "turn", "market_prompt" }, nil)
  tm.game.store:set({ "turn", "post_action" }, nil)
  tm.game.store:set({ "turn", "item_phase" }, {})
  tm.game.store:set({ "turn", "item_phase_active" }, "")
  tm:next_player()
  return nil
end

return _PhaseEnd
