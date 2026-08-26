local number_utils = require("src.foundation.number")

local tile_rent = {}

local function _max_level(tile)
  local costs = tile and tile.upgrade_costs or nil
  if type(costs) == "table" then
    return #costs
  end
  return 0
end

function tile_rent.for_level(tile, level)
  if tile == nil or tile.price == nil then
    return nil
  end
  local normalized_level = number_utils.clamp(level or 0, 0, _max_level(tile))
  return math.floor((tile.price * (2 ^ normalized_level)) * 0.5)
end

return tile_rent

--[[ mutate4lua-manifest
version=4
projectHash=1042093ead0fda5e
scope.0.id=chunk:src/ui/view/tile_rent.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=22
scope.0.semanticHash=357c43289eb99f93
scope.1.id=function:_max_level
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=dd909935a29c7d39
scope.2.id=function:tile_rent.for_level
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=04f4c0d9bf2e82ed
]]
