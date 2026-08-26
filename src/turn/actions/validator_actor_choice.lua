local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")
local choice_contract = require("src.config.choice.contract")

local validator_actor_choice = {}

local function _current_player(game)
  return game and game.current_player and game:current_player() or nil
end

local function _resolve_current_player_role_id(game)
  local current = _current_player(game)
  return current and number_utils.to_integer(current.id) or nil
end

local function _resolve_choice_owner_role_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return _resolve_current_player_role_id(game)
end

local function _action_type(action)
  return action and action.type or nil
end

local function _action_actor_role_id(action)
  return action and action.actor_role_id or nil
end

function validator_actor_choice.validate_choice_actor(game, action, choice)
  local actor_role_id = role_id_utils.normalize(_action_actor_role_id(action))
  if actor_role_id == nil then
    logger.warn("choice action missing actor_role_id:", tostring(_action_type(action)))
    return false
  end
  local owner_role_id = _resolve_choice_owner_role_id(game, choice)
  if owner_role_id ~= nil and not role_id_utils.equals(actor_role_id, owner_role_id) then
    logger.warn(
      "choice action blocked by actor check:",
      tostring(_action_type(action)),
      "actor_role_id=" .. tostring(actor_role_id),
      "owner_role_id=" .. tostring(owner_role_id)
    )
    return false
  end
  return true
end

function validator_actor_choice.validate_choice_id(action, choice)
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

local function _warn_missing_choice(action)
  logger.warn("choice action without pending choice:", tostring(action and action.type))
end

function validator_actor_choice.validate_choice_action(game, action, choice)
  if not choice or not choice.id then
    _warn_missing_choice(action)
    return false, "missing_choice"
  end
  if not validator_actor_choice.validate_choice_actor(game, action, choice) then
    return false, "choice_actor_mismatch"
  end
  if not validator_actor_choice.validate_choice_id(action, choice) then
    return false, "choice_id_mismatch"
  end
  return true
end

return validator_actor_choice

--[[ mutate4lua-manifest
version=4
projectHash=984cb0fbc42d0071
scope.0.id=chunk:src/turn/actions/validator_actor_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=87
scope.0.semanticHash=b760a5d56425f3d8
scope.1.id=function:_current_player
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=9ff044378783fe73
scope.2.id=function:_resolve_current_player_role_id
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=c6c577296c107741
scope.3.id=function:_resolve_choice_owner_role_id
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=23
scope.3.semanticHash=58dfcf56da450af4
scope.4.id=function:_action_type
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=27
scope.4.semanticHash=616a2ca60599c94f
scope.5.id=function:_action_actor_role_id
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=31
scope.5.semanticHash=616a2ca60599c94f
scope.6.id=function:validator_actor_choice.validate_choice_actor
scope.6.kind=function
scope.6.startLine=33
scope.6.endLine=50
scope.6.semanticHash=0e6e6f042ad188c7
scope.7.id=function:validator_actor_choice.validate_choice_id
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=66
scope.7.semanticHash=a3ef632e19e41790
scope.8.id=function:_warn_missing_choice
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=70
scope.8.semanticHash=75f76bcfdbc1814a
scope.9.id=function:validator_actor_choice.validate_choice_action
scope.9.kind=function
scope.9.startLine=72
scope.9.endLine=84
scope.9.semanticHash=e577683ece2773af
]]
