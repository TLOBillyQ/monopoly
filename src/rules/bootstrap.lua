local choice_registry_module = require("src.rules.choice.registry")
local chance_handlers = require("src.rules.chance.handlers")
local item_registry_module = require("src.rules.items.registry")
local choice_handler_factory = require("src.rules.choice_handlers.factory")
local effect_registry_module = require("src.rules.effects.registry")
local choice_resolver = require("src.rules.choice.resolver")
local land_executors = require("src.rules.land.executors")
local land_settlement = require("src.rules.land.settlement")
local item_phase = require("src.rules.items.phase")
local item_use_flow = require("src.rules.items.use_flow")
local market_effects = require("src.rules.market.effects")
local logger = require("src.foundation.log")
local availability = require("src.rules.items.availability")

local bootstrap = {}

local optional_effect_handler = {}

function optional_effect_handler.build(helpers)
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
    local result = land_settlement.resolve_landing_settlement_choice(game, choice, action)
    if result and result.ok == false then
      logger.warn("landing_optional_effect execute blocked:", tostring(result.reason))
    end
    if result and result.stay then
      return result
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
  return choice_resolver.helpers({
    begin_item_use = function(game, player, item_id, context)
      return item_use_flow.begin_item_use(game, player and player.id or nil, item_id, context)
    end,
    resolve_item_use_choice = item_use_flow.resolve_item_use_choice,
    finish_item_phase = function(game, choice)
      item_phase.finish(game, choice and choice.meta and choice.meta.phase or nil)
    end,
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

--[[ mutate4lua-manifest
version=2
projectHash=e324ebda6008f2f7
scope.0.id=chunk:src/rules/bootstrap.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=114
scope.0.semanticHash=9754cd40b2802709
scope.1.id=function:_normalize_optional_meta:22
scope.1.kind=function
scope.1.startLine=22
scope.1.endLine=28
scope.1.semanticHash=f08ed07e0a2df61c
scope.2.id=function:_validate_optional_meta:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=36
scope.2.semanticHash=871ea88d7979cc80
scope.3.id=function:_normalize_optional_action:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=43
scope.3.semanticHash=ebd0177c8a6f8d16
scope.4.id=function:_handle_optional_landing_effect:45
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=54
scope.4.semanticHash=a32067786cb21a72
scope.5.id=function:optional_effect_handler.build:19
scope.5.kind=function
scope.5.startLine=19
scope.5.endLine=65
scope.5.semanticHash=0ec1143e30feb0bf
scope.6.id=function:anonymous@71:71
scope.6.kind=function
scope.6.startLine=71
scope.6.endLine=73
scope.6.semanticHash=c70c136c7b5f99f6
scope.7.id=function:anonymous@75:75
scope.7.kind=function
scope.7.startLine=75
scope.7.endLine=77
scope.7.semanticHash=d9553649c296ae2d
scope.8.id=function:anonymous@78:78
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=83
scope.8.semanticHash=515b009b5e6fc8f8
scope.9.id=function:_build_choice_helpers:69
scope.9.kind=function
scope.9.startLine=69
scope.9.endLine=85
scope.9.semanticHash=4be379a0d0cead20
scope.10.id=function:_build_choice_groups:87
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=95
scope.10.semanticHash=4860bc0a11791c53
scope.11.id=function:bootstrap.create_registries:97
scope.11.kind=function
scope.11.startLine=97
scope.11.endLine=111
scope.11.semanticHash=4835f48cd75c83be
]]
