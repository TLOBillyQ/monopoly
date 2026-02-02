local Pricing = {}

local function _MaxLevel(tile)
  local costs = tile.upgrade_costs
  if type(costs) == "table" then
    return #costs
  end
  return 0
end

function Pricing.MaxLevel(tile)
  return _MaxLevel(tile)
end

function Pricing.PurchasePrice(tile)
  return tile.price
end

function Pricing.UpgradeCost(tile, level)
  local costs = tile.upgrade_costs
  if type(costs) ~= "table" then
    return 0
  end
  local idx = (level or 0) + 1
  return costs[idx] or 0
end

function Pricing.RentForLevel(tile, level)
  local rents = tile.rents
  if type(rents) ~= "table" then
    return 0
  end
  local idx = (level or 0) + 1
  return rents[idx] or 0
end

function Pricing.TotalInvested(tile, level)
  local total = Pricing.PurchasePrice(tile)
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

return Pricing
