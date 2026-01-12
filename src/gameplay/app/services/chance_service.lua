local chance_cfg = require("src.config.chance_cards")
local random = require("src.util.random")
local chance_effects = require("src.gameplay.effects.chance")

local ChanceService = {}

function ChanceService.draw_card(rng)
  return random.weighted_choice(chance_cfg, "weight", rng)
end
function ChanceService.resolve(game, player, card, context)
  return chance_effects.resolve(game, player, card, context)
end

return ChanceService
