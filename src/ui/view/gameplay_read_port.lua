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

-- 与 domain pricing 同语义:升级档位缺失按 0 计。不能用 #costs 封顶——带洞表
-- 的长度是未定义行为({10, nil, 40} 在 Lua 5.4 返回 3、5.5 返回 1),cap 只会让
-- read model 与 domain 在稀疏档位表上偏离(5.5 下 210 vs 250)。
local function _sum_upgrade_costs(costs, max_level)
  local total = 0
  for i = 1, max_level do
    total = total + (costs[i] or 0)
  end
  return total
end

function gameplay_read_port.total_land_invested(tile, level)
  local total = _purchase_price(tile)
  local costs = tile and tile.upgrade_costs or nil
  if type(costs) ~= "table" then
    return total
  end
  return total + _sum_upgrade_costs(costs, _normalize_level(level))
end

return gameplay_read_port

--[[ mutate4lua-manifest
version=4
projectHash=ea5168d13688dfd0
scope.0.id=chunk:src/ui/view/gameplay_read_port.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=e50af4e7bd737093
scope.1.id=function:_normalize_level
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=cc76062774865877
scope.2.id=function:_purchase_price
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=22
scope.2.semanticHash=44f92394bf760e92
scope.3.id=function:_sum_upgrade_costs
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=33
scope.3.semanticHash=854b787498770641
scope.4.id=function:gameplay_read_port.total_land_invested
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=42
scope.4.semanticHash=f4b0f65521332988
]]
