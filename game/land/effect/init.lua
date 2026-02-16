local chance = require("game.land.effect.chance")
local land = require("game.land.effect.land")
local tax = require("game.land.effect.tax")
local special = require("game.land.effect.special")
local misc = require("game.land.effect.misc")

local effect = {}

local executors = {
  pass_players = misc.pass_players_executor(),
  start_reward = misc.start_reward_executor(),
  item_draw_and_give = special.item_executor(),
  chance_draw_and_resolve = chance.executor(),
  hospital = special.hospital_executor(),
  mountain = special.mountain_executor(),
  market = special.market_executor(),
  buy_land = land.buy_executor(),
  upgrade_land = land.upgrade_executor(),
  pay_rent = land.rent_executor(),
  tax = tax.executor(),
  mine = misc.mine_executor(),
}

effect.executors = executors

function effect.register_effect_executors(effect_registry)
  assert(effect_registry ~= nil, "missing effect_registry")
  assert(effect_registry.register_many ~= nil, "invalid effect_registry")
  effect_registry:register_many(executors)
end

return effect
