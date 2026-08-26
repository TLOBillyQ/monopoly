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
version=4
projectHash=1c9c8d9efa0ef796
scope.0.id=chunk:src/rules/commerce/property_value.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=19ed1fadf74b3bbd
scope.1.id=function:_purchase_price
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=1bbe01328c10a955
scope.2.id=function:_upgrade_cost
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=13
scope.2.semanticHash=a609ff45c500da0a
scope.3.id=function:property_value.total_invested
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=23
scope.3.semanticHash=2a0e1a5db0174f80
]]
