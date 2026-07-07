require "vendor.third_party.ClassUtils"

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
version=2
projectHash=547b4be9db3650ab
scope.0.id=chunk:src/rules/choice/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=5d84508e8e2e8020
scope.0.lastMutatedAt=2026-07-07T03:32:29Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=19
scope.0.lastMutationKilled=19
scope.1.id=function:choice_registry:init:28
scope.1.kind=function
scope.1.startLine=28
scope.1.endLine=30
scope.1.semanticHash=3d4c6f87b0eef1f8
scope.2.id=function:choice_registry:register:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=35
scope.2.semanticHash=dfea91937bed5492
scope.2.lastMutatedAt=2026-07-07T03:32:29Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:choice_registry:descriptor_for:37
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=39
scope.3.semanticHash=92b987309cf25cc8
]]
