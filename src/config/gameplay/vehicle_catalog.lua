local vehicle_catalog = {}

function vehicle_catalog.list()
  return {}
end

function vehicle_catalog.find(_id)
  return nil
end

function vehicle_catalog.has(_id)
  return false
end

function vehicle_catalog.name_of(id)
  return tostring(id)
end

return vehicle_catalog
