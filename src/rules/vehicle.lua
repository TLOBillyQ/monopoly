local vehicle_catalog = require("src.config.gameplay.vehicle_catalog")

local vehicle_feature = {}

local _enabled = false

function vehicle_feature.set_enabled(enabled)
  _enabled = enabled == true
end

function vehicle_feature.is_enabled()
  return _enabled
end

function vehicle_feature.resolve_seat_id(seat_id)
  if seat_id == nil then
    return nil
  end
  if not vehicle_catalog.has(seat_id) then
    return nil
  end
  return seat_id
end

return vehicle_feature
