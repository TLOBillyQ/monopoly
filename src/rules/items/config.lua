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
version=4
projectHash=abd330fe7c342071
scope.0.id=chunk:src/rules/items/config.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=d811ad00b7282f07
scope.1.id=function:_build_cfg_by_id
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=f1b522140adafff9
]]
