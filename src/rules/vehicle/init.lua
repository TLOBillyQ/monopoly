local vehicle_feature = {}

function vehicle_feature.is_enabled()
  return false
end

function vehicle_feature.resolve_seat_id(_seat_id)
  return nil
end

function vehicle_feature.is_vehicle_market_entry(entry)
  return entry ~= nil and entry.kind == "vehicle"
end

function vehicle_feature.is_vehicle_chance_card(card)
  return card ~= nil and card.effect == "set_vehicle"
end

return vehicle_feature
