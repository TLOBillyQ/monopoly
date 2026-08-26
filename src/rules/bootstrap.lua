local choice_registry_module = require("src.rules.choice.registry")
local chance_handlers = require("src.rules.chance.handlers")
local item_registry_module = require("src.rules.items.registry")
local choice_handler_factory = require("src.rules.choice_handlers.factory")
local effect_registry_module = require("src.rules.effects.registry")
local choice_resolver = require("src.rules.choice.resolver")
local land_executors = require("src.rules.land.executors")
local item_phase = require("src.rules.items.phase")
local item_use_flow = require("src.rules.items.use_flow")
local market_effects = require("src.rules.market.effects")

local bootstrap = {}

local function _build_choice_helpers()
  return choice_resolver.helpers({
    begin_item_use = function(game, player, item_id, context)
      return item_use_flow.begin_item_use(game, player and player.id or nil, item_id, context)
    end,
    resolve_item_use_choice = item_use_flow.resolve_item_use_choice,
    finish_active_item_phase = function(game)
      local phase = game.turn.item_phase_active
      if phase and phase ~= "" then
        item_phase.finish(game, phase)
      end
    end,
  })
end

local function _build_choice_groups()
  local helpers = _build_choice_helpers()
  return {
    choice_handler_factory.build_landing_optional_handlers(helpers),
    choice_handler_factory.build_land_handlers(helpers),
    choice_handler_factory.build_item_handlers(helpers),
    choice_handler_factory.build_market_handlers(helpers),
  }
end

local function _build_effect_groups()
  return {
    land_executors.executors,
    market_effects.executors,
  }
end

function bootstrap.create_registries()
  local registries = {
    items = item_registry_module:new(),
    choices = choice_registry_module:new(),
    chances = chance_handlers.build(),
    effects = effect_registry_module:new(),
  }

  registries.items:register_defaults()
  registries.choices:register_defaults(_build_choice_groups())
  registries.effects:register_defaults(_build_effect_groups())

  return registries
end

return bootstrap

--[[ mutate4lua-manifest
version=4
projectHash=1768974f9add7466
scope.0.id=chunk:src/rules/bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=62
scope.0.semanticHash=f8215c61f18906be
scope.1.id=function:_build_choice_helpers
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=27
scope.1.semanticHash=76a09b06933c5da4
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=c14f8484fd09de2b
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=25
scope.3.semanticHash=2fcafdb5cf9bdc5e
scope.4.id=function:_build_choice_groups
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=37
scope.4.semanticHash=05704f5fe3291c19
scope.5.id=function:_build_effect_groups
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=44
scope.5.semanticHash=3bc532e00ee897f0
scope.6.id=function:bootstrap.create_registries
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=59
scope.6.semanticHash=c8bc3b6caba73179
]]
