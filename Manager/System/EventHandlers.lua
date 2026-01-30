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

local function register(event_name, fn)
  if not (LuaAPI and LuaAPI.global_register_custom_event) then
    return nil
  end
  return LuaAPI.global_register_custom_event(event_name, fn)
end

function EventHandlers.install(_, logger, ui_port)
  if not logger then
    return
  end
  if not (LuaAPI and LuaAPI.global_register_custom_event) then
    return
  end
  if installed then
    return
  end
  installed = true

  local function log_text(payload)
    if payload and payload.text then
      logger.event(payload.text)
    end
  end

  local function bind(event_name, fn)
    register(event_name, fn)
  end

  bind(MONOPOLY_EVENT.movement.moved, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.movement.passed_start, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.movement.roadblock_hit, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.movement.market_interrupt, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.movement.steal_interrupt, function(_, _, data)
    log_text(normalize_payload(data))
  end)

  bind(MONOPOLY_EVENT.land.rent_skipped_mountain, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.land.strong_card_used, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.land.free_rent_used, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.land.rent_paid, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.land.rent_bankrupt, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.land.tax_free, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.land.tax_paid, function(_, _, data)
    log_text(normalize_payload(data))
  end)

  bind(MONOPOLY_EVENT.market.bought_item, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.market.bought_vehicle, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.market.auto_skip, function(_, _, data)
    log_text(normalize_payload(data))
  end)
  bind(MONOPOLY_EVENT.market.buy_failed, function(_, _, data)
    local payload = normalize_payload(data)
    local popup = payload and payload.popup or nil
    if ui_port and ui_port.push_popup and popup then
      ui_port:push_popup(popup)
    end
  end)

  bind(MONOPOLY_EVENT.chance.applied, function(_, _, data)
    log_text(normalize_payload(data))
  end)
end

return EventHandlers
