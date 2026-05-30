local number_utils = require("src.foundation.number")
local rewards = require("src.config.content.sign_in_rewards")

-- The host sign-in panel fires custom events RewardDay1..RewardDay7 when a
-- player claims a day's reward; the Lua side only grants the configured coins.
-- The calendar gating (first login of day, claimable state, streak) stays in
-- the host panel.
local EVENT_PREFIX = "RewardDay"

local sign_in = {
  rewards = rewards,
  event_prefix = EVENT_PREFIX,
}

function sign_in.amount_for_day(day)
  return rewards[day]
end

-- "RewardDay3" -> 3; any name that is not RewardDay<positive-int> -> nil.
function sign_in.day_from_event(event_name)
  if type(event_name) ~= "string" then
    return nil
  end
  local digits = event_name:match("^" .. EVENT_PREFIX .. "(%d+)$")
  if digits == nil then
    return nil
  end
  return number_utils.to_integer(digits)
end

-- Grant the configured reward for `day` to `player`. No-op (returns false) when
-- the day has no configured reward or arguments are missing.
function sign_in.grant(game, player, day)
  local amount = day ~= nil and rewards[day] or nil
  if amount == nil or game == nil or player == nil then
    return false
  end
  game:add_player_cash(player, amount)
  return true
end

-- Boundary adapter: map a host reward event to a coin grant for the claiming
-- player. Unconfigured events grant nothing.
-- TODO_HOST_INTEGRATION: subscribe RewardDay1..7 via the host custom-event port
-- and resolve the claiming player from the host event data payload.
function sign_in.claim(game, event_name, player)
  local day = sign_in.day_from_event(event_name)
  if day == nil then
    return false
  end
  return sign_in.grant(game, player, day)
end

return sign_in

--[[ mutate4lua-manifest
version=2
projectHash=29f060df0bfba505
scope.0.id=chunk:src/app/host_integrations/sign_in.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=55
scope.0.semanticHash=2dd814c43ad0fc7e
scope.0.lastMutatedAt=2026-05-29T15:09:12Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:sign_in.amount_for_day:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=e983506d6f821945
scope.1.lastMutatedAt=2026-05-29T15:09:12Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=no_sites
scope.1.lastMutationSites=0
scope.1.lastMutationKilled=0
scope.2.id=function:sign_in.day_from_event:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=29
scope.2.semanticHash=6c4bf71af0810798
scope.2.lastMutatedAt=2026-05-29T15:09:12Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:sign_in.grant:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=40
scope.3.semanticHash=50e7a86eed20cd01
scope.3.lastMutatedAt=2026-05-29T15:09:12Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:sign_in.claim:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=52
scope.4.semanticHash=51c5f3b711ffe0f1
scope.4.lastMutatedAt=2026-05-29T15:09:12Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
]]
