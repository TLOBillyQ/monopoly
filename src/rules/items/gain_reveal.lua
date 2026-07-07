local event_kinds = require("src.config.gameplay.event_kinds")
local timing = require("src.config.gameplay.timing")
local action_anim_port = require("src.foundation.ports.action_anim")
local inventory = require("src.rules.items.inventory")

local gain_reveal = {}

function gain_reveal.queue(game, player, item_id, opts)
  if game == nil or player == nil or item_id == nil then
    return false
  end
  return action_anim_port.queue(game, {
    kind = event_kinds.item_get_reveal,
    player_id = player.id,
    owner_role_id = player.id,
    item_id = item_id,
    item_name = inventory.item_name(item_id),
    duration = timing.item_get_reveal_seconds,
    source = opts and opts.source or nil,
  })
end

return gain_reveal

--[[ mutate4lua-manifest
version=2
projectHash=74db5c9850f8b181
scope.0.id=chunk:src/rules/items/gain_reveal.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=24
scope.0.semanticHash=9086a181dc5ab797
scope.0.lastMutatedAt=2026-07-07T03:36:03Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:gain_reveal.queue:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=21
scope.1.semanticHash=d25fe3311f874055
scope.1.lastMutatedAt=2026-07-07T03:36:03Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
]]
