local base = require("src.rules.land.effect_base")
local chance = require("src.rules.land.effect_chance")
local transit = require("src.rules.land.effect_transit")
local special = require("src.rules.land.effect_special")

local module = {}

local function _merge_executor_groups(groups)
  local merged = {}
  for _, group in ipairs(groups) do
    for key, value in pairs(group) do
      merged[key] = value
    end
  end
  return merged
end

local executors = _merge_executor_groups({
  base.executors,
  chance.executors,
  transit.executors,
  special.executors,
})

module.executors = executors

-- Export helper for testability
module._merge_executor_groups = _merge_executor_groups

return module

--[[ mutate4lua-manifest
version=4
projectHash=0de9a5cd22db4d0c
scope.0.id=chunk:src/rules/land/executors.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=d607ffc8b2deb024
scope.1.id=function:_merge_executor_groups
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=16
scope.1.semanticHash=0c23c354ed03578c
]]
