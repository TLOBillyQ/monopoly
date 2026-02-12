local pricing = {}

local function _max_level(tile)
  local costs = tile.upgrade_costs
  if type(costs) == "table" then
    return #costs
  end
  return 0
end

function pricing.max_level(tile)
  return _max_level(tile)
end

function pricing.purchase_price(tile)
  return tile.price
end

function pricing.upgrade_cost(tile, level)
  local costs = tile.upgrade_costs
  if type(costs) ~= "table" then
    return 0
  end
  local idx = (level or 0) + 1
  return costs[idx] or 0
end

function pricing.rent_for_level(tile, level)
  local rents = tile.rents
  if type(rents) ~= "table" then
    return 0
  end
  local idx = (level or 0) + 1
  return rents[idx] or 0
end

function pricing.total_invested(tile, level)
  local total = pricing.purchase_price(tile)
  local costs = tile.upgrade_costs
  if type(costs) ~= "table" then
    return total
  end
  local max = level or 0
  local count = #costs
  if max > count then
    max = count
  end
  for i = 1, max do
    total = total + (costs[i] or 0)
  end
  return total
end

return pricing
