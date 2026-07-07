local choice_meta_validator = {}

local function _validate_required_meta(choice_spec, required_meta)
  if type(required_meta) ~= "table" or #required_meta == 0 then
    return choice_spec.meta
  end

  local meta = choice_spec.meta
  assert(type(meta) == "table", tostring(choice_spec.kind) .. " requires meta")
  for _, key in ipairs(required_meta) do
    assert(meta[key] ~= nil, tostring(choice_spec.kind) .. " requires meta." .. tostring(key))
  end
  return meta
end

local function _resolve_descriptor(game, choice_spec)
  local registries = game and game.registries
  local choice_registry = registries and registries.choices
  if type(choice_registry) ~= "table" or type(choice_registry.descriptor_for) ~= "function" then
    return nil
  end
  return choice_registry:descriptor_for(choice_spec.kind)
end

local function _apply_normalize_meta(game, descriptor, choice_spec)
  if descriptor and descriptor.normalize_meta ~= nil then
    local normalized_meta = descriptor.normalize_meta(game, choice_spec.meta, choice_spec)
    if normalized_meta ~= nil then
      choice_spec.meta = normalized_meta
    end
  end
end

local function _run_meta_validation(game, descriptor, choice_spec)
  local required_meta = descriptor and descriptor.required_meta
  local meta = _validate_required_meta(choice_spec, required_meta)
  if descriptor and descriptor.meta_validator ~= nil then
    descriptor.meta_validator(game, meta, choice_spec)
  end
end

function choice_meta_validator.validate(game, choice_spec)
  local descriptor = _resolve_descriptor(game, choice_spec)
  _apply_normalize_meta(game, descriptor, choice_spec)
  _run_meta_validation(game, descriptor, choice_spec)
  return descriptor
end

return choice_meta_validator

--[[ mutate4lua-manifest
version=2
projectHash=881620f08e886e36
scope.0.id=chunk:src/turn/output/choice_meta_validator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=24dcba3665f3b4d6
scope.1.id=function:_resolve_descriptor:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=23
scope.1.semanticHash=b856ad674e6d307c
scope.2.id=function:_apply_normalize_meta:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=32
scope.2.semanticHash=42b3fd1213631fcc
scope.3.id=function:_run_meta_validation:34
scope.3.kind=function
scope.3.startLine=34
scope.3.endLine=40
scope.3.semanticHash=101f03760fbcf30d
scope.4.id=function:choice_meta_validator.validate:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=47
scope.4.semanticHash=4be7cec3921f919a
]]
