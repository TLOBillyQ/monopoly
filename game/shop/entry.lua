local market_cfg = require("cfg.Generated.Market")
local items_cfg = require("cfg.Generated.Items")
local vehicles_cfg = require("cfg.Generated.Vehicles")
local vehicle_feature = require("game.vehicle")

local entry = {}

local items_by_id = {}
for _, cfg in ipairs(items_cfg) do
  items_by_id[cfg.id] = cfg
end

local vehicles_by_id = {}
for _, cfg in ipairs(vehicles_cfg) do
  vehicles_by_id[cfg.id] = cfg
end

local entries_by_id = {}
for _, e in ipairs(market_cfg) do
  entries_by_id[e.product_id] = e
end

function entry.get(product_id)
  return entries_by_id[product_id]
end

function entry.name(e)
  if e.kind == "vehicle" then
    local cfg = vehicles_by_id[e.product_id]
    if cfg then
      return cfg.name
    end
    return e.name or tostring(e.product_id)
  end
  local cfg = items_by_id[e.product_id]
  if cfg then
    return cfg.name
  end
  return e.name or tostring(e.product_id)
end

function entry.vehicle_name(seat_id)
  if not seat_id then
    return "无"
  end
  local cfg = vehicles_by_id[seat_id]
  return cfg and cfg.name or tostring(seat_id)
end

function entry.price(e)
  return e.price or 0
end

function entry.currency(e)
  local c = e.currency
  return (c and c ~= "") and c or "金币"
end

function entry.is_market_enabled(e)
  assert(e ~= nil, "missing market entry")
  return e.market_enabled ~= false
end

function entry.is_vehicle_enabled(e)
  if not vehicle_feature.is_vehicle_market_entry(e) then
    return true
  end
  return vehicle_feature.is_enabled()
end

function entry.all()
  local list = {}
  for _, e in ipairs(market_cfg) do
    table.insert(list, e)
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

return entry
