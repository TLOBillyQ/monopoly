local StatusService = require("src.gameplay.services.status_service")

local function phase_end(tm, args)
  local player = args.player
  StatusService.tick_end_of_turn(player)
  player:clear_temporal_flags()
  tm:next_player()
  return nil
end

return phase_end
