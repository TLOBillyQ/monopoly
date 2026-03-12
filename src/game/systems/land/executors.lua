local base = require("src.game.systems.land.effects.base")
local chance = require("src.game.systems.land.effects.chance")
local transit = require("src.game.systems.land.effects.transit")
local special = require("src.game.systems.land.effects.special")

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
