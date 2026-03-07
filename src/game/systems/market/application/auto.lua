local auto_play_port = require("src.game.ports.auto_play_port")
local monopoly_event = require("src.core.events.monopoly_events")
local query = require("src.game.systems.market.application.eligibility")
local purchase = require("src.game.systems.market.application.purchase")
local context = require("src.game.systems.market.application.context")

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

  local chosen = nil
  for _, entry in ipairs(list) do
    if entry.kind ~= "vehicle" or not player.seat_id then
      chosen = entry
      break
    end
  end
  if chosen then
    purchase.execute(game, player, chosen.product_id, { skip_vehicle_prompt = true })
  end
end

return auto

