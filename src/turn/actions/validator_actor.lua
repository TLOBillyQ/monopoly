local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")
local choice_contract = require("src.config.choice.contract")

local validator_actor = {}

local function _is_turn_bound_ui_button(action_id)
  return action_id == "next" or action_id and string.match(action_id, "^item_slot_(%d+)$") ~= nil
end

local function _resolve_current_player_role_id(game)
  local current = game and game.current_player and game:current_player() or nil
  return current and number_utils.to_integer(current.id) or nil
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return _resolve_current_player_role_id(game)
end

local function _resolve_current_turn_role_id(game)
  local current_index = game.turn.current_player_index
  local current_player = current_index and game.players and game.players[current_index] or nil
  return role_id_utils.normalize(current_player and current_player.id or nil)
end

local function _validate_actor_matches_current(action, actor_role_id, current_role_id)
  if actor_role_id == nil then
    logger.warn("ui_button missing actor_role_id:", tostring(action.id))
    return false
  end
  if current_role_id == nil then
    logger.warn("ui_button missing current_role_id:", tostring(action.id))
    return false
  end
  if not role_id_utils.equals(actor_role_id, current_role_id) then
    logger.warn(
      "ui_button blocked by actor check:",
      tostring(action.id),
      "actor_role_id=" .. tostring(actor_role_id),
      "current_role_id=" .. tostring(current_role_id)
    )
    return false
  end
  return true
end

function validator_actor.validate_actor_role(game, action)
  if not _is_turn_bound_ui_button(action and action.id) then
    return true
  end
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local current_role_id = _resolve_current_turn_role_id(game)
  local actor_role_id = role_id_utils.normalize(action.actor_role_id)
  return _validate_actor_matches_current(action, actor_role_id, current_role_id)
end

function validator_actor.validate_choice_actor(game, action, choice)
  local actor_role_id = role_id_utils.normalize(action and action.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("choice action missing actor_role_id:", tostring(action and action.type))
    return false
  end
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  if owner_role_id ~= nil and not role_id_utils.equals(actor_role_id, owner_role_id) then
    logger.warn(
      "choice action blocked by actor check:",
      tostring(action and action.type),
      "actor_role_id=" .. tostring(actor_role_id),
      "owner_role_id=" .. tostring(owner_role_id)
    )
    return false
  end
  return true
end

function validator_actor.validate_choice_id(action, choice)
  if not action or not choice then
    return false
  end
  if not action.choice_id or action.choice_id ~= choice.id then
    logger.warn(
      "choice action mismatch:",
      tostring(action.type),
      "action_choice_id=" .. tostring(action.choice_id),
      "pending_choice_id=" .. tostring(choice.id)
    )
    return false
  end
  return true
end

function validator_actor.validate_choice_action(game, action, choice)
  if not choice or not choice.id then
    logger.warn("choice action without pending choice:", tostring(action and action.type))
    return false
  end
  if not validator_actor.validate_choice_actor(game, action, choice) then
    return false
  end
  return validator_actor.validate_choice_id(action, choice)
end

return validator_actor

--[[ mutate4lua-manifest
version=2
projectHash=4a06a3e18ce058d4
scope.0.id=chunk:src/turn/actions/validator_actor.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=109
scope.0.semanticHash=ed6668556959f82e
scope.0.lastMutatedAt=2026-07-07T02:10:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:_is_turn_bound_ui_button:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=5fa9abe5a74cb137
scope.1.lastMutatedAt=2026-07-07T02:10:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:_resolve_current_player_role_id:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=09250e687842076d
scope.2.lastMutatedAt=2026-07-07T02:10:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:_resolve_choice_owner_role_id:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=23
scope.3.semanticHash=77559ad9d6b68d87
scope.3.lastMutatedAt=2026-07-07T02:10:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:_resolve_current_turn_role_id:25
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=29
scope.4.semanticHash=d117c2d3ca8e57a5
scope.4.lastMutatedAt=2026-07-07T02:10:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
scope.5.id=function:_validate_actor_matches_current:31
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=50
scope.5.semanticHash=8c57c548b617e591
scope.5.lastMutatedAt=2026-07-07T02:10:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=11
scope.5.lastMutationKilled=11
scope.6.id=function:validator_actor.validate_actor_role:52
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=60
scope.6.semanticHash=d00308d79d17c2c6
scope.6.lastMutatedAt=2026-07-07T02:10:24Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:validator_actor.validate_choice_actor:62
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=79
scope.7.semanticHash=6f212956ae19a3b8
scope.7.lastMutatedAt=2026-07-07T02:10:24Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=12
scope.7.lastMutationKilled=12
scope.8.id=function:validator_actor.validate_choice_id:81
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=95
scope.8.semanticHash=9239a9dcc254a7ae
scope.8.lastMutatedAt=2026-07-07T02:10:24Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=10
scope.8.lastMutationKilled=10
scope.9.id=function:validator_actor.validate_choice_action:97
scope.9.kind=function
scope.9.startLine=97
scope.9.endLine=106
scope.9.semanticHash=f71654d05adea2a6
scope.9.lastMutatedAt=2026-07-07T02:10:24Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=9
scope.9.lastMutationKilled=9
]]
