local TileService = require("src.gameplay.services.tile_service")
local LandResolver = require("src.gameplay.land_resolver")

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)
  local res = TileService.resolve(tm.game, player, tile, move_result)
  if res and res.waiting then
    local resume_state = res.resume_state or "land"
    local resume_args = res.resume_args or { player = player, move_result = move_result }
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  local res_effects = LandResolver.resolve(tm.game, player, tile, move_result)
  if res_effects and res_effects.waiting then
    local resume_state = res_effects.resume_state or "end_turn"
    local resume_args = res_effects.resume_args or { player = player }
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  return "end_turn", { player = player }
end

return phase_land
