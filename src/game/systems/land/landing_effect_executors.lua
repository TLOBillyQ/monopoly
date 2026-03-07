local base_land = require("src.game.systems.land.landing_effects.base_land_effects")
local chance = require("src.game.systems.land.landing_effects.chance_effects")
local market = require("src.game.systems.land.landing_effects.market_effects")
local transit = require("src.game.systems.land.landing_effects.transit_effects")
local special = require("src.game.systems.land.landing_effects.special_tile_effects")

local landing_effect_executors = {}

local executors = {}
for k, v in pairs(base_land.executors) do executors[k] = v end
for k, v in pairs(chance.executors) do executors[k] = v end
for k, v in pairs(market.executors) do executors[k] = v end
for k, v in pairs(transit.executors) do executors[k] = v end
for k, v in pairs(special.executors) do executors[k] = v end

landing_effect_executors.executors = executors

function landing_effect_executors.register_effect_executors(effect_registry)
  assert(effect_registry ~= nil, "missing effect_registry")
  assert(effect_registry.register_many ~= nil, "invalid effect_registry")
  effect_registry:register_many(executors)
end

return landing_effect_executors
