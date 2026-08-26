local land_settlement = require("src.rules.land.settlement")
local landing_result = require("src.rules.choice_handlers.landing_result")
local availability = require("src.rules.items.availability")
local logger = require("src.foundation.log")

local M = {}

local function _build(helpers)
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
    return landing_result.settle(finish_choice, game, result)
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

function M.register(registry, helpers)
  local handlers = _build(helpers)
  for kind, handler in pairs(handlers) do
    registry[kind] = handler
  end
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=87e196fc61ba2060
scope.0.id=chunk:src/rules/choice_handlers/landing_optional.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=61
scope.0.semanticHash=8e0786dc19e98754
scope.1.id=function:_build
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=51
scope.1.semanticHash=6c3aeb320bec3dd4
scope.2.id=function:_normalize_optional_meta
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=17
scope.2.semanticHash=1b33ee9eb6386522
scope.3.id=function:_validate_optional_meta
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=25
scope.3.semanticHash=b2fb25fb54a157e5
scope.4.id=function:_normalize_optional_action
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=32
scope.4.semanticHash=533cc6aa42f9291c
scope.5.id=function:_handle_optional_landing_effect
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=40
scope.5.semanticHash=c2de06ae8031203b
scope.6.id=function:M.register
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=58
scope.6.semanticHash=eeb3a7c61f5feb12
]]
