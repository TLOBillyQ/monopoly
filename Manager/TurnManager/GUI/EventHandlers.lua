local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local EventHandlers = {}
local installed = false

local function normalize_payload(data)
  if type(data) ~= "table" then
    return data
  end
  if data.text ~= nil or data.popup ~= nil then
    return data
  end
  if data["1"] ~= nil then
    return data["1"]
  end
  return data
end

function EventHandlers.install(_, logger, ui_port)
  if not logger then
    return
  end
  if not RegisterCustomEvent then
    return
  end
  if installed then
    return
  end
  installed = true

  local register = RegisterCustomEvent

  local function log_text(payload)
    if payload and payload.text then
      logger.event(payload.text)
    end
  end

  local function log_payload(_, _, data)
    log_text(normalize_payload(data))
  end

  local handlers = {
    { MONOPOLY_EVENT.movement.moved, log_payload },
    { MONOPOLY_EVENT.movement.passed_start, log_payload },
    { MONOPOLY_EVENT.movement.roadblock_hit, log_payload },
    { MONOPOLY_EVENT.movement.market_interrupt, log_payload },
    { MONOPOLY_EVENT.movement.steal_interrupt, log_payload },
    { MONOPOLY_EVENT.land.rent_skipped_mountain, log_payload },
    { MONOPOLY_EVENT.land.strong_card_used, log_payload },
    { MONOPOLY_EVENT.land.free_rent_used, log_payload },
    { MONOPOLY_EVENT.land.rent_paid, log_payload },
    { MONOPOLY_EVENT.land.rent_bankrupt, log_payload },
    { MONOPOLY_EVENT.land.tax_free, log_payload },
    { MONOPOLY_EVENT.land.tax_paid, log_payload },
    { MONOPOLY_EVENT.market.bought_item, log_payload },
    { MONOPOLY_EVENT.market.bought_vehicle, log_payload },
    { MONOPOLY_EVENT.market.auto_skip, log_payload },
    { MONOPOLY_EVENT.market.buy_failed, function(_, _, data)
        local payload = normalize_payload(data)
        local popup = payload and payload.popup or nil
        if ui_port and ui_port.push_popup and popup then
          ui_port:push_popup(popup)
        end
      end },
    { MONOPOLY_EVENT.chance.applied, log_payload },
  }

  for _, entry in ipairs(handlers) do
    register(entry[1], entry[2])
  end
end

return EventHandlers
