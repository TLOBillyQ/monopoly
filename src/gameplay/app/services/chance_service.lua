local chance_cfg = require("src.config.chance_cards")
local random = require("src.util.random")
local chance_effects = require("src.gameplay.domain.chance")
local LandingResolver = require("src.gameplay.app.landing_resolver")

local ChanceService = {}


function ChanceService.draw_card(rng)
  return random.weighted_choice(chance_cfg, "weight", rng)
end

function ChanceService.resolve(game, player, card, context)
  local res = chance_effects.resolve(game, player, card, context)
  if type(res) == "table" and res.kind == "need_landing" then
    local target_player = (res.player_id and game and game.players and game.players[res.player_id]) or player
    if not target_player then
      return nil
    end
    local idx = res.board_index or res.tile_index or target_player.position
    local tile = idx and game and game.board and game.board:get_tile(idx) or nil
    if not tile then
      return nil
    end
    return LandingResolver.resolve(game, target_player, tile, res.move_result)
  end
  return res
end

return ChanceService
