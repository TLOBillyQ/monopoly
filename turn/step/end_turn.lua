local logger = require("core.logger")

local function _phase_end_turn(turn_mgr, args)
  local player = args.player
  local game = turn_mgr.game

  logger.info("[Eggy] 回合结束:", tostring(player.name))

  game:stop_all_players_movement()

  -- Switch to next player and restart the turn flow
  turn_mgr:next_player()

  return "start", { player = game:current_player() }
end

return _phase_end_turn
