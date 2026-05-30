local property_value = {}

local function _purchase_price(tile)
  assert(tile ~= nil, "missing tile")
  return tile.price or 0
end

local function _upgrade_cost(tile, level)
  assert(tile ~= nil, "missing tile")
  local costs = tile.upgrade_costs or {}
  local next_level = (level or 0) + 1
  return costs[next_level] or 0
end

function property_value.total_invested(tile, level)
  assert(tile ~= nil, "missing tile")
  local total = _purchase_price(tile)
  local max_level = level or 0
  for current_level = 0, max_level - 1 do
    total = total + _upgrade_cost(tile, current_level)
  end
  return total
end

return property_value

--[[ mutate4lua-manifest
version=2
projectHash=9da2c97ba1b83442
scope.0.id=chunk:src/rules/commerce/property_value.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=7fa654cb14c9241e
scope.1.id=function:_purchase_price:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=948c619ab183cf22
scope.2.id=function:_upgrade_cost:8
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=13
scope.2.semanticHash=b155d0932aabed12
]]
