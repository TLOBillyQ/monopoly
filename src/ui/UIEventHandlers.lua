local monopoly_event = require("src.game.MonopolyEvents")

local event_handlers = {}
local installed = false

function event_handlers.install(_, logger, ui_port)
  if installed then
    return
  end
  installed = true

  local log_events = {
    monopoly_event.movement.moved,
    monopoly_event.movement.passed_start,
    monopoly_event.movement.roadblock_hit,
    monopoly_event.movement.market_interrupt,
    monopoly_event.movement.steal_interrupt,
    monopoly_event.land.rent_skipped_mountain,
    monopoly_event.land.strong_card_used,
    monopoly_event.land.free_rent_used,
    monopoly_event.land.rent_paid,
    monopoly_event.land.rent_bankrupt,
    monopoly_event.land.tax_free,
    monopoly_event.land.tax_paid,
    monopoly_event.market.bought_item,
    monopoly_event.market.bought_vehicle,
    monopoly_event.market.auto_skip,
    monopoly_event.chance.applied,
  }

  for _, event_name in ipairs(log_events) do
    RegisterCustomEvent(event_name, function(_, _, data)
      if data.text then
        logger.event(data.text)
      end
    end)
  end

  RegisterCustomEvent(monopoly_event.market.buy_failed, function(_, _, data)
    local popup = data.popup
    if popup then
      ui_port:push_popup(popup)
    end
  end)
end

return event_handlers
