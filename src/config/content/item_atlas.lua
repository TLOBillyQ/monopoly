local items = require("src.config.content.items")

local item_atlas = {}

for index, item in ipairs(items) do
  item_atlas[index] = {
    id = item.id,
    key = item.key,
    name = item.name,
    description = item.description,
    usage = item.usage,
    tier = item.tier,
  }
end

return item_atlas

--[[ mutate4lua-manifest
version=2
projectHash=c50ab0b99d9396a0
scope.0.id=chunk:src/config/content/item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=90874f36004c30bc
]]
