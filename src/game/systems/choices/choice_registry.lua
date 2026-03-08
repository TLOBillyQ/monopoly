require "vendor.third_party.ClassUtils"

local choice_kind_aliases = require("src.game.systems.choices.choice_kind_aliases")

local choice_registry = Class("ChoiceRegistry")

local function _normalize_descriptor(kind, handler)
  local canonical_kind = choice_kind_aliases.to_canonical(kind)
  if type(handler) == "function" then
    return canonical_kind, {
      execute = handler,
    }
  end

  assert(type(handler) == "table", "choice handler must be function or table")
  local descriptor = {}
  for key, value in pairs(handler) do
    descriptor[key] = value
  end
  assert(type(descriptor.execute) == "function", "choice descriptor missing execute: " .. tostring(canonical_kind))
  return canonical_kind, descriptor
end

function choice_registry:init()
  self.handlers = {}
end

function choice_registry:register(kind, handler)
  local canonical_kind, descriptor = _normalize_descriptor(kind, handler)
  self.handlers[canonical_kind] = descriptor
end

function choice_registry:descriptor_for(kind)
  local canonical_kind = choice_kind_aliases.to_canonical(kind)
  return self.handlers[canonical_kind]
end

function choice_registry:register_defaults(helpers)
  local groups = {
    require("src.game.systems.choices.choice_handlers.optional_effect_handler").build(helpers),
    require("src.game.systems.choices.choice_handlers.land_choice_handler").build(helpers),
    require("src.game.systems.choices.choice_handlers.item_choice_handler").build(helpers),
    require("src.game.systems.choices.choice_handlers.market_choice_handler").build(helpers),
  }
  for _, group in ipairs(groups) do
    for key, handler in pairs(group) do
      self:register(key, handler)
    end
  end
end

return choice_registry
