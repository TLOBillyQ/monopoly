local effect_runner = require("src.rules.effects.runner")
local intent_output_port = require("src.rules.ports.intent_output")
local landing_defs = require("src.rules.land.landing_defs")
local tables = require("src.foundation.tables")
local shared = require("src.rules.land.settlement_shared")

local effect_choice = {}

local function _find_effect_by_id(effect_id)
  for _, effect_definition in ipairs(landing_defs) do
    if effect_definition.id == effect_id then
      return effect_definition
    end
  end
  return nil
end

local function _option_id(option)
  return type(option) == "table" and option.id or option
end

local function _same_option(current, option_id)
  return current == option_id or tostring(current) == tostring(option_id)
end

local function _options_of(choice)
  return choice.options or {}
end

local function _option_is_offered(choice, option_id)
  if choice == nil or option_id == nil then
    return false
  end
  for _, option in ipairs(_options_of(choice)) do
    if _same_option(_option_id(option), option_id) then
      return true
    end
  end
  return false
end

local function _landing_optional_effect_id(action)
  local effect_id = shared.option_id_from_action(action)
  if effect_id == nil or effect_id == "" then
    return nil, shared.reject("missing_landing_option")
  end
  return effect_id
end

local function _validate_landing_option(choice, meta, effect_id)
  if meta.effect_ids and not tables.contains(meta.effect_ids, effect_id) then
    return shared.reject("landing_option_not_offered")
  end
  if not _option_is_offered(choice, effect_id) then
    return shared.reject("landing_option_not_offered")
  end
  return nil
end

local function _resolve_landing_effect(effect_id)
  local target_effect = _find_effect_by_id(effect_id)
  if target_effect == nil then
    return nil, shared.reject("landing_effect_not_found")
  end
  return target_effect
end

local function _resolve_landing_effect_target(choice, action)
  local effect_id, effect_id_error = _landing_optional_effect_id(action)
  if effect_id_error then return nil, effect_id_error end

  local meta, meta_error = shared.choice_meta(choice)
  if meta_error then return nil, meta_error end

  local option_error = _validate_landing_option(choice, meta, effect_id)
  if option_error then return nil, option_error end

  local target_effect, effect_error = _resolve_landing_effect(effect_id)
  if effect_error then return nil, effect_error end

  return {
    effect_id = effect_id,
    meta = meta,
    target_effect = target_effect,
  }
end

local function _resolve_landing_effect_actor_tile(game, meta)
  local player, player_error = shared.resolve_choice_player(game, meta)
  if player_error then return nil, nil, player_error end

  local tile, tile_error = shared.resolve_choice_tile(game, player, meta)
  if tile_error then return nil, nil, tile_error end

  return player, tile
end

local function _execute_landing_optional_target(game, target, player, tile)
  local result = effect_runner.execute(
    target.target_effect,
    player,
    tile,
    shared.build_game_ctx(game, target.meta.move_result, "wait_choice")
  )
  intent_output_port.dispatch(game, result.result or result)
  if result.ok ~= true then
    return shared.reject(result.reason or "landing_effect_blocked")
  end
  return {
    ok = true,
    status = "resolved",
    effect_id = target.effect_id,
    result = result.result,
  }
end

function effect_choice.resolve(game, choice, action)
  local target, target_error = _resolve_landing_effect_target(choice, action)
  if target_error then return target_error end

  local player, tile, player_tile_error = _resolve_landing_effect_actor_tile(game, target.meta)
  if player_tile_error then return player_tile_error end

  return _execute_landing_optional_target(game, target, player, tile)
end

effect_choice._M_test = {
  _option_is_offered = _option_is_offered,
}

return effect_choice

--[[ mutate4lua-manifest
version=4
projectHash=5e188658efebd505
scope.0.id=chunk:src/rules/land/settlement_effect_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=132
scope.0.semanticHash=648d6b0622d5bcde
scope.1.id=function:_find_effect_by_id
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=16
scope.1.semanticHash=857ff1f1536fd2da
scope.2.id=function:_option_id
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=a21febbf33b567dd
scope.3.id=function:_same_option
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=24
scope.3.semanticHash=28eaf336aecd24e7
scope.4.id=function:_options_of
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=55894c6cd2a6d2d5
scope.5.id=function:_option_is_offered
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=40
scope.5.semanticHash=6c72d03b779abaa5
scope.6.id=function:_landing_optional_effect_id
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=48
scope.6.semanticHash=1d64c8953c44e76d
scope.7.id=function:_validate_landing_option
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=58
scope.7.semanticHash=56a116e55a52f6e7
scope.8.id=function:_resolve_landing_effect
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=66
scope.8.semanticHash=cf39887142ec9123
scope.9.id=function:_resolve_landing_effect_target
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=86
scope.9.semanticHash=187fa313e3930341
scope.10.id=function:_resolve_landing_effect_actor_tile
scope.10.kind=function
scope.10.startLine=88
scope.10.endLine=96
scope.10.semanticHash=31549f37ea451012
scope.11.id=function:_execute_landing_optional_target
scope.11.kind=function
scope.11.startLine=98
scope.11.endLine=115
scope.11.semanticHash=8f74c9ef96fb9699
scope.12.id=function:effect_choice.resolve
scope.12.kind=function
scope.12.startLine=117
scope.12.endLine=125
scope.12.semanticHash=eb04238a9ba5e5ac
]]
