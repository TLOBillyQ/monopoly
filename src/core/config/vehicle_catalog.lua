local vehicles_cfg = require("Config.generated.vehicles")

local vehicle_catalog = {}

local by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  assert(cfg.id ~= nil, "vehicle config missing id")
  assert(by_id[cfg.id] == nil, "duplicate vehicle id: " .. tostring(cfg.id))
  by_id[cfg.id] = cfg
end

function vehicle_catalog.list()
  return vehicles_cfg
end

function vehicle_catalog.find(id)
  return by_id[id]
end

function vehicle_catalog.has(id)
  return by_id[id] ~= nil
end

function vehicle_catalog.name_of(id)
  local cfg = by_id[id]
  if cfg and cfg.name then
    return cfg.name
  end
  return tostring(id)
end

return vehicle_catalog
