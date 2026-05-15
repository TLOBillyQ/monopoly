local choice_registry_module = require("src.rules.choice.registry")
local chance_handlers = require("src.rules.chance.handlers")
local item_registry_module = require("src.rules.items.registry")
local choice_handler_factory = require("src.rules.choice_handlers.factory")
local effect_registry_module = require("src.rules.effects.registry")
local effect_runner = require("src.rules.effects.runner")
local choice_resolver = require("src.rules.choice.resolver")
local land_executors = require("src.rules.land.executors")
local landing_defs = require("src.rules.land.landing_defs")
local item_executor = require("src.rules.items.executor")
local item_phase = require("src.rules.items.phase")
local market_effects = require("src.rules.market.effects")
local logger = require("src.foundation.log")
local intent_output_port = require("src.rules.ports.intent_output")
local availability = require("src.rules.items.availability")

local bootstrap = {}

local optional_effect_handler = {}

function optional_effect_handler.build(helpers)
  local build_game_ctx = helpers.build_game_ctx
  local get_container_defs_by_choice_kind = helpers.get_container_defs_by_choice_kind
  local find_effect_by_id = helpers.find_effect_by_id
  local finish_choice = helpers.finish_choice

  local function _normalize_optional_meta(game, meta, choice_spec)
    local normalized_meta = availability.copy_table(meta)
    availability.normalize_integer_field(normalized_meta, "player_id", choice_spec.kind)
    availability.normalize_integer_field(normalized_meta, "tile_id", choice_spec.kind)
    choice_spec.owner_role_id = choice_spec.owner_role_id or normalized_meta.player_id
    return normalized_meta
  end

  local function _validate_optional_meta(game, meta, choice_spec)
    assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(game.board:get_tile_by_id(meta.tile_id), "missing tile: " .. tostring(meta.tile_id))
    if meta.effect_ids ~= nil then
      assert(type(meta.effect_ids) == "table", tostring(choice_spec.kind) .. " requires table meta.effect_ids")
    end
  end

  local function _normalize_optional_action(_, _, action)
    local normalized_action = availability.copy_table(action)
    assert(type(normalized_action.option_id) == "string" and normalized_action.option_id ~= "",
      "landing_optional_effect requires string action.option_id")
    return normalized_action
  end

  local function _handle_optional_landing_effect(game, choice, action)
    local effect_id = assert(action.option_id, "missing effect_id")
    local meta = choice.meta

    if meta.effect_ids and not availability.contains(meta.effect_ids, effect_id) then
      logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local effect_defs = get_container_defs_by_choice_kind(choice.kind)
    local target_effect = assert(find_effect_by_id(effect_defs, effect_id), "missing target effect: " .. tostring(effect_id))

    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local tile = assert(game.board:get_tile_by_id(meta.tile_id), "missing tile: " .. tostring(meta.tile_id))
    local move_result = meta.move_result
    local game_ctx = build_game_ctx(game, move_result)

    local result = effect_runner.execute(target_effect, player, tile, game_ctx)
    intent_output_port.dispatch(game, result.result or result)
    if result.ok ~= true then
      logger.warn("landing_optional_effect execute blocked:", tostring(result and result.reason))
    end
    return finish_choice(game, false)
  end

  return {
    landing_optional_effect = {
      required_meta = { "player_id", "tile_id" },
      normalize_meta = _normalize_optional_meta,
      meta_validator = _validate_optional_meta,
      normalize_action = _normalize_optional_action,
      execute = _handle_optional_landing_effect,
    },
  }
end

bootstrap.optional_effect_handler = optional_effect_handler

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
    optional_effect_handler.build(helpers),
    choice_handler_factory.build_land_handlers(helpers),
    choice_handler_factory.build_item_handlers(helpers),
    choice_handler_factory.build_market_handlers(helpers),
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
