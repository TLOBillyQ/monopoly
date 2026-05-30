local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local use_broadcast = require("src.rules.items.use_broadcast")
local number_utils = require("src.foundation.number")

local dice_multiplier = {}

local function _resolve_pending_multiplier(player)
  local pending_multiplier = player.status.pending_dice_multiplier
  if not pending_multiplier or pending_multiplier <= 1 then
    return 1
  end
  return pending_multiplier
end

function dice_multiplier.apply_roll_total(raw_total, player)
  local pending_multiplier = _resolve_pending_multiplier(player)
  if pending_multiplier <= 1 then
    return raw_total
  end
  return raw_total * pending_multiplier
end

function dice_multiplier.apply_move_total(game, player, total, raw_total)
  local pending_multiplier = _resolve_pending_multiplier(player)
  if pending_multiplier <= 1 or raw_total == nil or total ~= raw_total then
    return total
  end

  local new_total = raw_total * pending_multiplier
  if game.set_player_status then
    game:set_player_status(player, "pending_dice_multiplier", 1)
  else
    player.status.pending_dice_multiplier = 1
  end
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
projectHash=3d24835d829f7b0b
scope.0.id=chunk:src/turn/phases/dice_multiplier.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=a2b816c2287368e4
scope.1.id=function:_resolve_pending_multiplier:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=15
scope.1.semanticHash=359eab6db9691e5b
scope.2.id=function:dice_multiplier.apply_roll_total:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=23
scope.2.semanticHash=bcadc50a17d0987a
scope.3.id=function:dice_multiplier.apply_move_total:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=50
scope.3.semanticHash=5943c3c966e0af53
]]
