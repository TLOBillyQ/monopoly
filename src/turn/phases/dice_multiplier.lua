local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local use_broadcast = require("src.rules.items.use_broadcast")
local number_utils = require("src.foundation.number")

local dice_multiplier = {}

function dice_multiplier.apply_roll_total(game, raw_total, player)
  -- player_pending_dice_multiplier normalizes to >= 1, so multiplying is a
  -- no-op when no multiplier is pending.
  return raw_total * game:player_pending_dice_multiplier(player)
end

function dice_multiplier.apply_move_total(game, player, total, raw_total)
  local pending_multiplier = game:player_pending_dice_multiplier(player)
  if pending_multiplier <= 1 or raw_total == nil or total ~= raw_total then
    return total
  end

  local new_total = raw_total * game:consume_pending_dice_multiplier(player)
  if game.last_turn then
    game.last_turn.total = new_total
  end
  use_broadcast.dispatch(game, player, item_ids.dice_multiplier)
  event_feed.publish(game, {
    kind = event_kinds.item_used,
    text = player.name
      .. " 骰子加倍卡生效，步数 "
      .. number_utils.format_integer_part(raw_total)
      .. " → "
      .. number_utils.format_integer_part(new_total),
  })
  return new_total
end

return dice_multiplier

--[[ mutate4lua-manifest
version=2
projectHash=e5dc743fd8ec2f39
scope.0.id=chunk:src/turn/phases/dice_multiplier.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=38
scope.0.semanticHash=fd851290b8d7bb67
scope.0.lastMutatedAt=2026-07-07T09:55:50Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:dice_multiplier.apply_roll_total:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=13
scope.1.semanticHash=cad71c8fb6dac043
scope.1.lastMutatedAt=2026-07-07T09:55:50Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:dice_multiplier.apply_move_total:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=35
scope.2.semanticHash=27a4557a3cdf74bc
scope.2.lastMutatedAt=2026-07-07T09:55:50Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=11
scope.2.lastMutationKilled=11
]]
