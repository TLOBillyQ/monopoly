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
function sign_in.claim(game, event_name, player)
  local day = sign_in.day_from_event(event_name)
  if day == nil then
    return false
  end
  return sign_in.grant(game, player, day)
end

-- Subscribe RewardDay1..7 to the host custom-event port and credit the claiming
-- player when a day is claimed. Dependencies are injected so this stays testable;
-- the only untestable thin slice is `register_event` (the host LuaAPI call):
--   register_event(name, handler)  -- handler is invoked by the host as (_, _, data)
--   get_game()                     -- the live game, or nil before one exists
--   resolve_role_id(data)          -- the claiming player's role id from the payload
function sign_in.install(deps)
  assert(type(deps) == "table", "missing sign_in install deps")
  local register_event = assert(deps.register_event, "missing register_event")
  local get_game = assert(deps.get_game, "missing get_game")
  local resolve_role_id = assert(deps.resolve_role_id, "missing resolve_role_id")
  local after_grant = deps.after_grant
  for day = 1, #rewards do
    register_event(EVENT_PREFIX .. day, function(_, _, data)
      local game = get_game()
      if game == nil then
        return
      end
      local role_id = resolve_role_id(data)
      local player = role_id ~= nil and type(game.find_player_by_id) == "function"
        and game:find_player_by_id(role_id) or nil
      if sign_in.grant(game, player, day) and type(after_grant) == "function" then
        after_grant(game, player, day)
      end
    end)
  end
end

return sign_in

--[[ mutate4lua-manifest
version=2
projectHash=32a2c46fbb5ee57e
scope.0.id=chunk:src/app/host_integrations/sign_in.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=78
scope.0.semanticHash=c226c206ab2f5539
scope.0.lastMutatedAt=2026-05-31T03:28:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=9
scope.0.lastMutationKilled=9
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
scope.2.lastMutatedAt=2026-05-31T03:28:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:sign_in.grant:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=40
scope.3.semanticHash=50e7a86eed20cd01
scope.3.lastMutatedAt=2026-05-31T03:28:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:sign_in.claim:44
scope.4.kind=function
scope.4.startLine=44
scope.4.endLine=50
scope.4.semanticHash=51c5f3b711ffe0f1
scope.4.lastMutatedAt=2026-05-31T03:28:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
scope.5.id=function:anonymous@64:64
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=73
scope.5.semanticHash=cd5bb05dea07a6e5
scope.5.lastMutatedAt=2026-05-31T03:28:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=no_sites
scope.5.lastMutationSites=0
scope.5.lastMutationKilled=0
]]
