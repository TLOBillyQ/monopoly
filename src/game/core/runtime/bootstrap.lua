local choice_registry_module = require("src.game.systems.choices.registry")
local choice_optional_effect_handler = require("src.game.systems.choices.handlers.optional_effect")
local chance_handlers = require("src.game.systems.chance.chance_handlers")
local item_registry_module = require("src.game.systems.items.registry")
local item_choice_handlers = require("src.game.systems.items.choice_handlers")
local effect_registry_module = require("src.game.systems.effects.effect_registry")
local effect_runner = require("src.game.systems.effects.effect_runner")
local land_choice_handlers = require("src.game.systems.land.choice_handlers")
local choice_resolver = require("src.game.systems.choices.resolver")
local land_executors = require("src.game.systems.land.executors")
local landing_defs = require("src.game.systems.land.specs.effects")
local item_executor = require("src.game.systems.items.executor")
local item_phase = require("src.game.systems.items.phase")
local market_effects = require("src.game.systems.market.effects")
local market_choice_handlers = require("src.game.systems.market.choice_handlers")

local bootstrap = {}

local function _build_choice_helpers()
  local function _build_game_ctx(game, move_result)
    return effect_runner.build_game_ctx(game, move_result, {
      phase_default = "wait_choice",
      on_landing = true,
    })
  end

  local function _get_container_defs_by_choice_kind(choice_kind)
    if choice_kind == "landing_optional_effect" then
      return landing_defs
    end
    return nil
  end

  local function _find_effect_by_id(effect_defs, effect_id)
    assert(effect_defs ~= nil, "missing effect defs")
    for _, effect_definition in ipairs(effect_defs) do
      if effect_definition.id == effect_id then
        return effect_definition
      end
    end
    return nil
  end

  return choice_resolver.helpers({
    use_item = item_executor.use_item,
    build_game_ctx = _build_game_ctx,
    finish_item_phase = function(game, choice)
      item_phase.finish(game, choice and choice.meta and choice.meta.phase or nil)
    end,
    finish_active_item_phase = function(game)
      local phase = game.turn.item_phase_active
      if phase and phase ~= "" then
        item_phase.finish(game, phase)
      end
    end,
    get_container_defs_by_choice_kind = _get_container_defs_by_choice_kind,
    find_effect_by_id = _find_effect_by_id,
  })
end

local function _build_choice_groups()
  local helpers = _build_choice_helpers()
  return {
    choice_optional_effect_handler.build(helpers),
    land_choice_handlers.build(helpers),
    item_choice_handlers.build(helpers),
    market_choice_handlers.build(helpers),
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
  land_executors.register_effect_executors(registries.effects)
  market_effects.register_effect_executors(registries.effects)

  return registries
end

return bootstrap
