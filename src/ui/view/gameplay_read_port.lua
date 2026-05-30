local number_utils = require("src.foundation.number")

local gameplay_read_port = {}

local function _normalize_level(level)
  local as_int = number_utils.to_integer(level)
  if as_int == nil or as_int < 0 then
    return 0
  end
  return as_int
end

local function _purchase_price(tile)
  if type(tile) ~= "table" then
    return 0
  end
  local price = tile.price
  if not number_utils.is_numeric(price) then
    return 0
  end
  return price
end

function gameplay_read_port.total_land_invested(tile, level)
  local total = _purchase_price(tile)
  local costs = tile and tile.upgrade_costs or nil
  if type(costs) ~= "table" then
    return total
  end
  local max_level = _normalize_level(level)
  local max_cost_index = #costs
  if max_level > max_cost_index then
    max_level = max_cost_index
  end
  for i = 1, max_level do
    total = total + (costs[i] or 0)
  end
  return total
end

return gameplay_read_port

--[[ mutate4lua-manifest
version=2
projectHash=030540ed33f0b371
scope.0.id=chunk:src/ui/view/gameplay_read_port.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=1cf14273cbc94116
scope.1.id=function:_normalize_level:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=9a28e034c40de18b
scope.2.id=function:_purchase_price:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=22
scope.2.semanticHash=7948d596fff4f1c8
]]
