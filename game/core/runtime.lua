local effect_registry = require("game.effect.registry")
local item_registry = require("game.item.registry")
local choice_registry = require("choice")
local choice_resolve = require("choice.resolve")
local chance = require("chance")
local land_effects = require("game.land.effect")

local runtime = {}

function runtime.create_registries()
  local effects = effect_registry:new()
  local items = item_registry:new()
  local choices = choice_registry:new()
  local chances = chance.registry:new()

  items:register_defaults()
  chances:register_defaults()
  land_effects.register_effect_executors(effects)
  choices:register_defaults(choice_resolve.helpers())

  return {
    effects = effects,
    items = items,
    choices = choices,
    chances = chances,
  }
end

return runtime
