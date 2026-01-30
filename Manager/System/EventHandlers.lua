local EventHandlers = {}

local function bind(events, kind, fn)
  if events and events.on then
    events:on(kind, fn)
  end
end

function EventHandlers.install(game, logger, ui_port)
  if not (game and game.events and logger) then
    return
  end
  local events = game.events
  if events._handlers_installed then
    return
  end
  events._handlers_installed = true

  local function log_text(payload)
    if payload and payload.text then
      logger.event(payload.text)
    end
  end

  bind(events, "movement.moved", log_text)
  bind(events, "movement.passed_start", log_text)
  bind(events, "movement.roadblock_hit", log_text)
  bind(events, "movement.market_interrupt", log_text)
  bind(events, "movement.steal_interrupt", log_text)

  bind(events, "land.rent_skipped_mountain", log_text)
  bind(events, "land.strong_card_used", log_text)
  bind(events, "land.free_rent_used", log_text)
  bind(events, "land.rent_paid", log_text)
  bind(events, "land.rent_bankrupt", log_text)
  bind(events, "land.tax_free", log_text)
  bind(events, "land.tax_paid", log_text)

  bind(events, "market.bought_item", log_text)
  bind(events, "market.bought_vehicle", log_text)
  bind(events, "market.auto_skip", log_text)
  bind(events, "market.buy_failed", function(payload)
    local popup = payload and payload.popup or nil
    if ui_port and ui_port.push_popup and popup then
      ui_port:push_popup(popup)
    end
  end)

  bind(events, "chance.applied", log_text)
end

return EventHandlers
