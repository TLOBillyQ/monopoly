local gameplay_rules = require("cfg.GameplayRules")

local vehicle = {}

function vehicle.is_enabled()
  return gameplay_rules.vehicle_enabled == true
end

function vehicle.resolve_seat_id(seat_id)
  if not vehicle.is_enabled() then
    return nil
  end
  return seat_id
end

function vehicle.is_vehicle_market_entry(entry)
  return entry ~= nil and entry.kind == "vehicle"
end

function vehicle.is_vehicle_chance_card(card)
  return card ~= nil and card.effect == "set_vehicle"
end

return vehicle
