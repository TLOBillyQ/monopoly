local M = {}

local _option_id_set = {}
local _cached_option_choice_ref

local function _option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

local function _clear_option_id_set()
  for k in pairs(_option_id_set) do
    _option_id_set[k] = nil
  end
end

function M.build(choice)
  if not (choice and type(choice.options) == "table") then
    return _option_id_set
  end
  if choice.options == _cached_option_choice_ref then
    return _option_id_set
  end
  _cached_option_choice_ref = choice.options
  _clear_option_id_set()
  for _, option in ipairs(choice.options) do
    local option_id = _option_id(option)
    if option_id ~= nil then
      _option_id_set[tostring(option_id)] = true
    end
  end
  return _option_id_set
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=65c0932dc2e279ba
scope.0.id=chunk:src/ui/coord/item_slots_options.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=38
scope.0.semanticHash=6541a5f7f0912719
scope.0.lastMutatedAt=2026-06-24T20:10:43Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:_option_id:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=98f906d7086c6bf6
scope.1.lastMutatedAt=2026-06-24T20:10:43Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
]]
