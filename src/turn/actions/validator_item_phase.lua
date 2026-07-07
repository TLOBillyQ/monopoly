local logger = require("src.foundation.log")
local availability = require("src.rules.items.availability")

local validator_item_phase = {}

local function _choice_has_item_option(choice, item_id)
  local options = assert(choice.options, "missing choice options")
  for _, option in ipairs(options) do
    if (option.id or option) == item_id then
      return true
    end
  end
  return false
end

function validator_item_phase.validate_item_phase_option(choice, item_id)
  if _choice_has_item_option(choice, item_id) then
    return true
  end
  logger.warn("invalid item option:", tostring(item_id))
  return false
end

local function _resolve_item_phase_actor(runtime_game, actor_role_id)
  if not runtime_game or type(runtime_game.find_player_by_id) ~= "function" then
    return nil
  end
  return runtime_game:find_player_by_id(actor_role_id)
end

function validator_item_phase.validate_item_phase_availability(runtime_game, choice, actor_role_id, item_id)
  local actor = _resolve_item_phase_actor(runtime_game, actor_role_id)
  local phase = choice and choice.meta and choice.meta.phase or nil
  if not actor or type(phase) ~= "string" or phase == "" then
    return true
  end
  local can_offer = availability.can_offer_in_phase(runtime_game, actor, item_id, phase)
  if can_offer then
    return true
  end
  logger.warn("item slot denied by availability:", tostring(item_id), tostring(phase))
  return false
end

function validator_item_phase.validate_item_slot_action(runtime_game, choice, action, item_id)
  if not validator_item_phase.validate_item_phase_option(choice, item_id) then
    return false
  end
  if not validator_item_phase.validate_item_phase_availability(runtime_game, choice, action.actor_role_id, item_id) then
    return false
  end
  return true
end

return validator_item_phase

--[[ mutate4lua-manifest
version=2
projectHash=b809b755062378cb
scope.0.id=chunk:src/turn/actions/validator_item_phase.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=56
scope.0.semanticHash=3803cf0c9d90212a
scope.0.lastMutatedAt=2026-07-07T02:10:44Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
scope.1.id=function:validator_item_phase.validate_item_phase_option:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=22
scope.1.semanticHash=4c643d0511a53f85
scope.1.lastMutatedAt=2026-07-07T02:10:44Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_resolve_item_phase_actor:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=29
scope.2.semanticHash=957b90940ed474b7
scope.2.lastMutatedAt=2026-07-07T02:10:44Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:validator_item_phase.validate_item_phase_availability:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=43
scope.3.semanticHash=f23aebad3c61ebed
scope.3.lastMutatedAt=2026-07-07T02:10:44Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=17
scope.3.lastMutationKilled=17
scope.4.id=function:validator_item_phase.validate_item_slot_action:45
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=53
scope.4.semanticHash=cc8b0e96381552eb
scope.4.lastMutatedAt=2026-07-07T02:10:44Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
]]
