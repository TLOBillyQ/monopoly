local choice_registry_module = require("src.game.systems.choices.ChoiceRegistry")
local chance_registry_module = require("src.game.systems.chance.ChanceRegistry")
local item_registry_module = require("src.game.systems.items.ItemRegistry")
local effect_registry_module = require("src.game.systems.effects.EffectRegistry")
local choice_resolver = require("src.game.systems.choices.ChoiceResolver")
local landing_effect_executors = require("src.game.systems.land.LandingEffectExecutors")

local bootstrap = {}

function bootstrap.create_registries()
  local registries = {
    items = item_registry_module:new(),
    choices = choice_registry_module:new(),
    chances = chance_registry_module:new(),
    effects = effect_registry_module:new(),
  }

  registries.items:register_defaults()
  registries.choices:register_defaults(choice_resolver.helpers())
  registries.chances:register_defaults()
  landing_effect_executors.register_effect_executors(registries.effects)

  return registries
end

return bootstrap
