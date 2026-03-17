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

local function _clamp_upgrade_level(level, max_level)
  if level == nil or level <= 0 then
    return 0
  end
  if level > max_level then
    return max_level
  end
  return level
end

function pricing.total_invested(tile, level)
  local total = pricing.purchase_price(tile)
  local costs = tile.upgrade_costs
  if type(costs) ~= "table" then
    return total
  end
  for i = 1, _clamp_upgrade_level(level, #costs) do
    total = total + (costs[i] or 0)
  end
  return total
end

return pricing
