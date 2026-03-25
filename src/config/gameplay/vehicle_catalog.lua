local vehicles = require("src.config.content.vehicles")

local vehicle_catalog = {}

local _by_id = {}

for _, entry in ipairs(vehicles) do
  _by_id[entry.id] = entry
end

function vehicle_catalog.list()
  return vehicles
end

function vehicle_catalog.find(id)
  if id == nil then
    return nil
  end
  return _by_id[id]
end

function vehicle_catalog.has(id)
  return _by_id[id] ~= nil
end

function vehicle_catalog.name_of(id)
  local entry = _by_id[id]
  if entry then
    return entry.name
  end
  return tostring(id)
end

return vehicle_catalog
