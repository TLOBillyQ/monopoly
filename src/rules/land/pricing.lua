local number_utils = require("src.foundation.number")

local pricing = {}

local function _max_level(tile)
  local costs = tile.upgrade_costs
  if type(costs) == "table" then
    return #costs
  end
  return 0
end

pricing.max_level = _max_level

local function _purchase_price(tile)
  return tile.price
end

local function _level_indexed(tile, field, level)
  local arr = tile[field]
  if type(arr) ~= "table" then
    return 0
  end
  return arr[(level or 0) + 1] or 0
end

function pricing.upgrade_cost(tile, level)
  return _level_indexed(tile, "upgrade_costs", level)
end

function pricing.rent_for_level(tile, level)
  if tile and tile.price ~= nil then
    local normalized_level = number_utils.clamp(level or 0, 0, _max_level(tile))
    return math.floor((tile.price * (2 ^ normalized_level)) * 0.5)
  end
  return _level_indexed(tile, "rents", level)
end

function pricing.total_invested(tile, level)
  local total = _purchase_price(tile)
  local costs = tile.upgrade_costs
  if type(costs) ~= "table" then
    return total
  end
  for i = 1, level do
    total = total + (costs[i] or 0)
  end
  return total
end

return pricing

--[[ mutate4lua-manifest
version=4
projectHash=3507f0d26b90567d
scope.0.id=chunk:src/rules/land/pricing.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=52
scope.0.semanticHash=ddd149b80503f459
scope.1.id=function:_max_level
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=d9e12dacae500e0a
scope.2.id=function:_purchase_price
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=c0484ae42c9068b0
scope.3.id=function:_level_indexed
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=25
scope.3.semanticHash=a6778de56be44eff
scope.4.id=function:pricing.upgrade_cost
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=9ae0d7098f2d7ecb
scope.5.id=function:pricing.rent_for_level
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=37
scope.5.semanticHash=d4f4c82c854470f3
scope.6.id=function:pricing.total_invested
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=49
scope.6.semanticHash=36b5485a44c66305
]]
