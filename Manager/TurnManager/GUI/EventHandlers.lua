local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local EventHandlers = {}
local installed = false

function EventHandlers.install(_, logger, ui_port)
  if installed then
    return
  end
  installed = true

  local log_events = {
    MONOPOLY_EVENT.movement.moved,
    MONOPOLY_EVENT.movement.passed_start,
    MONOPOLY_EVENT.movement.roadblock_hit,
    MONOPOLY_EVENT.movement.market_interrupt,
    MONOPOLY_EVENT.movement.steal_interrupt,
    MONOPOLY_EVENT.land.rent_skipped_mountain,
    MONOPOLY_EVENT.land.strong_card_used,
    MONOPOLY_EVENT.land.free_rent_used,
    MONOPOLY_EVENT.land.rent_paid,
    MONOPOLY_EVENT.land.rent_bankrupt,
    MONOPOLY_EVENT.land.tax_free,
    MONOPOLY_EVENT.land.tax_paid,
    MONOPOLY_EVENT.market.bought_item,
    MONOPOLY_EVENT.market.bought_vehicle,
    MONOPOLY_EVENT.market.auto_skip,
    MONOPOLY_EVENT.chance.applied,
  }

  for _, event_name in ipairs(log_events) do
    RegisterCustomEvent(event_name, function(_, _, data)
      if data.text then
        logger.event(data.text)
      end
    end)
  end

  RegisterCustomEvent(MONOPOLY_EVENT.market.buy_failed, function(_, _, data)
    local popup = data.popup
    if popup then
      ui_port:push_popup(popup)
    end
  end)
end

return EventHandlers
