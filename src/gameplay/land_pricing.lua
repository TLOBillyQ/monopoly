local Pricing = {}

local function max_level(tile)
  local costs = tile and tile.upgrade_costs
  if type(costs) == "table" then
    return #costs
  end
  return 0
end

function Pricing.max_level(tile)
  return max_level(tile)
end

function Pricing.purchase_price(tile)
  return (tile and tile.price) or 0
end

function Pricing.upgrade_cost(tile, level)
  local costs = tile and tile.upgrade_costs
  if type(costs) ~= "table" then
    return 0
  end
  local idx = (level or 0) + 1
  return costs[idx] or 0
end

function Pricing.rent_for_level(tile, level)
  local rents = tile and tile.rents
  if type(rents) ~= "table" then
    return 0
  end
  local idx = (level or 0) + 1
  return rents[idx] or 0
end

function Pricing.total_invested(tile, level)
  local total = Pricing.purchase_price(tile)
  local costs = tile and tile.upgrade_costs
  if type(costs) ~= "table" then
    return total
  end
  local max = math.min(level or 0, #costs)
  for i = 1, max do
    total = total + (costs[i] or 0)
  end
  return total
end

return Pricing