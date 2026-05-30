local items_cfg = require("src.config.content.items")

local item_config = {}

local function _build_cfg_by_id()
  local cfg_by_id = {}
  for _, cfg in ipairs(items_cfg) do
    cfg_by_id[cfg.id] = cfg
  end
  return cfg_by_id
end

item_config.cfg_by_id = _build_cfg_by_id()

return item_config

--[[ mutate4lua-manifest
version=2
projectHash=5b1528a7a915ae55
scope.0.id=chunk:src/rules/items/config.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=6c6a646a635744d3
]]
