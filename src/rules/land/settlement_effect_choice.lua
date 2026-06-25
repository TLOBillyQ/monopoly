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

local function _option_is_offered(choice, option_id)
  if choice == nil or option_id == nil then
    return false
  end
  for _, option in ipairs(choice.options or {}) do
    local current = _option_id(option)
    if current == option_id or tostring(current) == tostring(option_id) then
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
version=2
projectHash=5e97d6f11acf5889
scope.0.id=chunk:src/rules/land/settlement_effect_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=125
scope.0.semanticHash=c1cab0c0df2c7270
scope.0.lastMutatedAt=2026-06-24T15:58:40Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=20
scope.0.lastMutationKilled=20
scope.1.id=function:_option_id:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=20
scope.1.semanticHash=7005f93308644da7
scope.1.lastMutatedAt=2026-06-24T15:58:40Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_landing_optional_effect_id:35
scope.2.kind=function
scope.2.startLine=35
scope.2.endLine=41
scope.2.semanticHash=8af12b04546efb8e
scope.2.lastMutatedAt=2026-06-24T15:58:40Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_validate_landing_option:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=51
scope.3.semanticHash=20a03e209eafd49f
scope.3.lastMutatedAt=2026-06-24T15:58:40Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_resolve_landing_effect:53
scope.4.kind=function
scope.4.startLine=53
scope.4.endLine=59
scope.4.semanticHash=f2e9bf9015a918ca
scope.4.lastMutatedAt=2026-06-24T15:58:40Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:_resolve_landing_effect_target:61
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=79
scope.5.semanticHash=d4b8c366da6338a9
scope.5.lastMutatedAt=2026-06-24T15:58:40Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=4
scope.5.lastMutationKilled=4
scope.6.id=function:_resolve_landing_effect_actor_tile:81
scope.6.kind=function
scope.6.startLine=81
scope.6.endLine=89
scope.6.semanticHash=f7c70c5cbc283d51
scope.6.lastMutatedAt=2026-06-24T15:58:40Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:_execute_landing_optional_target:91
scope.7.kind=function
scope.7.startLine=91
scope.7.endLine=108
scope.7.semanticHash=792c2e07498b5226
scope.7.lastMutatedAt=2026-06-24T15:58:40Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=7
scope.7.lastMutationKilled=7
scope.8.id=function:effect_choice.resolve:110
scope.8.kind=function
scope.8.startLine=110
scope.8.endLine=118
scope.8.semanticHash=09a0d23a024083b6
scope.8.lastMutatedAt=2026-06-24T15:58:40Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
]]
