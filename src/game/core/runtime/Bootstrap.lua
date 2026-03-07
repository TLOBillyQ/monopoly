local choice_registry_module = require("src.game.systems.choices.choice_registry")
local chance_handlers = require("src.game.systems.chance.chance_handlers")
local item_registry_module = require("src.game.systems.items.item_registry")
local effect_registry_module = require("src.game.systems.effects.effect_registry")
local choice_resolver = require("src.game.systems.choices.choice_resolver")
local landing_effect_executors = require("src.game.systems.land.landing_effect_executors")

local bootstrap = {}

function bootstrap.create_registries()
  local registries = {
    items = item_registry_module:new(),
    choices = choice_registry_module:new(),
    chances = chance_handlers.build(),
    effects = effect_registry_module:new(),
  }

  registries.items:register_defaults()
  registries.choices:register_defaults(choice_resolver.helpers())
  landing_effect_executors.register_effect_executors(registries.effects)

  return registries
end

return bootstrap
