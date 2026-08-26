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
version=4
projectHash=771a2f2d1ab976cd
scope.0.id=chunk:src/turn/output/choice_meta_validator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=50
scope.0.semanticHash=4bbd91419a8d3576
scope.1.id=function:_validate_required_meta
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=14
scope.1.semanticHash=d7215f5d369f740e
scope.2.id=function:_resolve_descriptor
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=23
scope.2.semanticHash=7da644a703a318dc
scope.3.id=function:_apply_normalize_meta
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=32
scope.3.semanticHash=20149f0229f07778
scope.4.id=function:_run_meta_validation
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=40
scope.4.semanticHash=60c3fc9516ba477d
scope.5.id=function:choice_meta_validator.validate
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=47
scope.5.semanticHash=d4c3c44009e8fc7d
]]
