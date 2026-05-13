local auto_play_port = require("src.rules.ports.auto_play")
local monopoly_event = require("src.foundation.events")
local query = require("src.rules.market.query.eligibility")
local purchase = require("src.rules.market.purchase.core")
local context = require("src.rules.market.query.context")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")

local auto = {}
local _emit_event = monopoly_event.emit

function auto.execute(game, player)
  if auto_play_port.is_auto_player(game, player) then
    local text = player.name .. " (AI) 到达黑市，选择不购买"
    _emit_event(monopoly_event.market.auto_skip, {
      player = player,
      text = text,
    })
    event_feed.publish(game, {
      kind = event_kinds.choice_skipped,
      text = text,
      tip = false,
    })
    return
  end

  local list = query.list_available(player, game)
  table.sort(list, function(a, b)
    return (context.entry_price(a) or 0) < (context.entry_price(b) or 0)
  end)

  if #list <= 0 then
    return
  end

  local chosen = list[1]
  if chosen then
    purchase.execute(game, player, chosen.product_id, nil)
  end
end

return auto
