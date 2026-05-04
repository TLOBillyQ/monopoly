local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local use_broadcast = require("src.rules.items.use_broadcast")
local number_utils = require("src.foundation.lang.number")

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
