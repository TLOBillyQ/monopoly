local LandingResolver = require("src.gameplay.landing_resolver")

local function phase_land(tm, args)
  local player = args.player
  local move_result = args.move_result
  local tile = tm.game.board:get_tile(player.position)

  local res = LandingResolver.resolve(tm.game, player, tile, move_result)
  if res and res.waiting then
    local resume_state = res.resume_state or "land"
    local resume_args = res.resume_args or { player = player, move_result = move_result }
    return "wait_choice", { resume_state = resume_state, resume_args = resume_args }
  end

  return "end_turn", { player = player }
end

return phase_land
