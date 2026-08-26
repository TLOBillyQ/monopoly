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
version=4
projectHash=69427485150ab9a3
scope.0.id=chunk:src/config/content/item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=be9dc32c207422d9
]]
