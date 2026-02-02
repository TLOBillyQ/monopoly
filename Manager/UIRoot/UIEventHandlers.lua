local MonopolyEvent = require("Globals.MonopolyEvents")

local EventHandlers = {}
local installed = false

function EventHandlers.install(_, logger, ui_port)
  if installed then
    return
  end
  installed = true

  local log_events = {
    MonopolyEvent.movement.moved,
    MonopolyEvent.movement.passed_start,
    MonopolyEvent.movement.roadblock_hit,
    MonopolyEvent.movement.market_interrupt,
    MonopolyEvent.movement.steal_interrupt,
    MonopolyEvent.land.rent_skipped_mountain,
    MonopolyEvent.land.strong_card_used,
    MonopolyEvent.land.free_rent_used,
    MonopolyEvent.land.rent_paid,
    MonopolyEvent.land.rent_bankrupt,
    MonopolyEvent.land.tax_free,
    MonopolyEvent.land.tax_paid,
    MonopolyEvent.market.bought_item,
    MonopolyEvent.market.bought_vehicle,
    MonopolyEvent.market.auto_skip,
    MonopolyEvent.chance.applied,
  }

  for _, event_name in ipairs(log_events) do
    RegisterCustomEvent(event_name, function(_, _, data)
      if data.text then
        logger.event(data.text)
      end
    end)
  end

  RegisterCustomEvent(MonopolyEvent.market.buy_failed, function(_, _, data)
    local popup = data.popup
    if popup then
      ui_port:push_popup(popup)
    end
  end)
end

return EventHandlers
