require "vendor.third_party.ClassUtils"

local choice_registry = Class("ChoiceRegistry")

local function _normalize_descriptor(kind, handler)
  if type(handler) == "function" then
    return kind, {
      execute = handler,
    }
  end

  assert(type(handler) == "table", "choice handler must be function or table")
  local descriptor = {}
  for key, value in pairs(handler) do
    descriptor[key] = value
  end
  assert(type(descriptor.execute) == "function", "choice descriptor missing execute: " .. tostring(kind))
  if descriptor.required_meta ~= nil then
    assert(type(descriptor.required_meta) == "table", "choice descriptor required_meta must be table: " .. tostring(kind))
  end
  if descriptor.normalize_meta ~= nil then
    assert(type(descriptor.normalize_meta) == "function", "choice descriptor normalize_meta must be function: " .. tostring(kind))
  end
  if descriptor.meta_validator ~= nil then
    assert(type(descriptor.meta_validator) == "function", "choice descriptor meta_validator must be function: " .. tostring(kind))
  end
  if descriptor.normalize_action ~= nil then
    assert(type(descriptor.normalize_action) == "function", "choice descriptor normalize_action must be function: " .. tostring(kind))
  end
  return kind, descriptor
end

function choice_registry:init()
  self.handlers = {}
end

function choice_registry:register(kind, handler)
  local normalized_kind, descriptor = _normalize_descriptor(kind, handler)
  self.handlers[normalized_kind] = descriptor
end

function choice_registry:descriptor_for(kind)
  return self.handlers[kind]
end

function choice_registry:register_defaults(groups)
  for _, group in ipairs(groups or {}) do
    for key, handler in pairs(group) do
      self:register(key, handler)
    end
  end
end

return choice_registry
