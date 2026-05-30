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

function module.register_effect_executors(effect_registry)
  assert(effect_registry ~= nil, "missing effect_registry")
  assert(effect_registry.register_many ~= nil, "invalid effect_registry")
  effect_registry:register_many(executors)
end

-- Export helper for testability
module._merge_executor_groups = _merge_executor_groups

return module

--[[ mutate4lua-manifest
version=2
projectHash=3792092a1a6a13e8
scope.0.id=chunk:src/rules/land/executors.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=9a58574c809a79db
scope.1.id=function:module.register_effect_executors:27
scope.1.kind=function
scope.1.startLine=27
scope.1.endLine=31
scope.1.semanticHash=0dcc1acfc9cbdfcb
]]
