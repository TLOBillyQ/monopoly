local auto_play_port = require("src.rules.ports.auto_play")
local monopoly_event = require("src.core.events.monopoly_events")
local query = require("src.rules.market.query.eligibility")
local purchase = require("src.rules.market.purchase.core")
local context = require("src.rules.market.query.context")

local auto = {}
local _emit_event = monopoly_event.emit

function auto.execute(game, player)
  if auto_play_port.is_auto_player(game, player) then
    _emit_event(monopoly_event.market.auto_skip, {
      player = player,
      text = player.name .. " (AI) 到达黑市，选择不购买",
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
