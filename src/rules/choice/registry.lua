local Class = require("src.foundation.class")

local choice_registry = Class("ChoiceRegistry")

local _optional_field_types = {
  required_meta = "table",
  normalize_meta = "function",
  meta_validator = "function",
  normalize_action = "function",
}

local function _validate_descriptor_fields(kind, descriptor)
  assert(type(descriptor.execute) == "function", "choice descriptor missing execute: " .. tostring(kind))
  for field, expected in pairs(_optional_field_types) do
    if descriptor[field] ~= nil then assert(type(descriptor[field]) == expected, "choice descriptor " .. field .. " must be " .. expected .. ": " .. tostring(kind)) end
  end
end

local function _normalize_descriptor(kind, handler)
  if type(handler) == "function" then return kind, { execute = handler } end
  assert(type(handler) == "table", "choice handler must be function or table")
  local descriptor = {}
  for key, value in pairs(handler) do descriptor[key] = value end
  _validate_descriptor_fields(kind, descriptor)
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

--[[ mutate4lua-manifest
version=4
projectHash=97f4b8633c9af324
scope.0.id=chunk:src/rules/choice/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=b2f23776e52c9982
scope.1.id=function:_validate_descriptor_fields
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=17
scope.1.semanticHash=dcee7da930cb4193
scope.2.id=function:_normalize_descriptor
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=26
scope.2.semanticHash=197d2d8c113ceb9b
scope.3.id=function:choice_registry:init
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=71cf7d660694c7cf
scope.4.id=function:choice_registry:register
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=35
scope.4.semanticHash=e12ab0ab5da0f96b
scope.5.id=function:choice_registry:descriptor_for
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=39
scope.5.semanticHash=70ade069282003e1
scope.6.id=function:choice_registry:register_defaults
scope.6.kind=function
scope.6.startLine=41
scope.6.endLine=47
scope.6.semanticHash=d16105866e9469cd
]]
