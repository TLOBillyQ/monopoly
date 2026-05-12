local monopoly_event = require("src.foundation.events")

local feedback = {}
local _emit_event = monopoly_event.emit

local popup_title = "黑市"

function feedback.emit_buy_failed(player, entry, reason, body)
  _emit_event(monopoly_event.market.buy_failed, {
    player = player,
    entry = entry,
    reason = reason,
    popup = { title = popup_title, body = body },
  })
end

function feedback.emit_inventory_full(player, entry)
  _emit_event(monopoly_event.market.inventory_full, {
    player = player,
    entry = entry,
    body = "卡槽已满，无法继续购买",
  })
end

return feedback
