local items_cfg = require("src.config.content.items")

local item_ids = {}

local function _register_item(map, cfg)
  if not (cfg and cfg.key and cfg.key ~= "") then return end
  assert(map[cfg.key] == nil, "duplicate item key in items config: " .. tostring(cfg.key))
  map[cfg.key] = cfg.id
end

for _, cfg in ipairs(items_cfg) do
  _register_item(item_ids, cfg)
end

item_ids._register_item = _register_item

return item_ids

--[[ mutate4lua-manifest
version=2
projectHash=6605a233bc542066
scope.0.id=chunk:src/config/gameplay/item_ids.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=18
scope.0.semanticHash=6dde0ca57a05806b
scope.0.lastMutatedAt=2026-07-07T03:20:17Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_register_item:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=9
scope.1.semanticHash=3c9fcbb5facc4495
scope.1.lastMutatedAt=2026-07-07T03:20:17Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
]]
