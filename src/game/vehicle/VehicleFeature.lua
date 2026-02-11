local gameplay_rules = require("Config.GameplayRules")

local vehicle_feature = {}

function vehicle_feature.is_enabled()
  return gameplay_rules.vehicle_enabled == true
end

function vehicle_feature.resolve_seat_id(seat_id)
  if not vehicle_feature.is_enabled() then
    return nil
  end
  return seat_id
end

function vehicle_feature.is_vehicle_market_entry(entry)
  return entry ~= nil and entry.kind == "vehicle"
end

function vehicle_feature.is_vehicle_chance_card(card)
  return card ~= nil and card.effect == "set_vehicle"
end

return vehicle_feature
