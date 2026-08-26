local M = {}

function M.resolve_option_id(option)
  return type(option) == "table" and option.id or option
end

local function _options_of(choice)
  return choice and choice.options or nil
end

local function _find_option(choice, predicate)
  local options = _options_of(choice)
  if type(options) ~= "table" then
    return nil
  end
  for _, option in ipairs(options) do
    local option_id = M.resolve_option_id(option)
    if predicate(option, option_id) then
      return option, option_id
    end
  end
  return nil
end

function M.resolve_option_label(option)
  if type(option) == "table" then
    return option.label or (option.id ~= nil and tostring(option.id)) or tostring(option)
  end
  return tostring(option)
end

function M.resolve_option_by_id(choice, option_id)
  if option_id == nil then
    return nil
  end
  local option = _find_option(choice, function(_, current_option_id)
    return current_option_id == option_id
  end)
  return type(option) == "table" and option or nil
end

function M.resolve_option_label_by_id(choice, option_id)
  local option, matched_option_id = _find_option(choice, function(_, current_option_id)
    return current_option_id == option_id
  end)
  if option == nil then
    return nil
  end
  return type(option) == "table" and option.label or tostring(matched_option_id)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=2dfd8ba6582e0730
scope.0.id=chunk:src/ui/view/choice_options.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=fbcc6f3001c4a5db
scope.1.id=function:M.resolve_option_id
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=a21febbf33b567dd
scope.2.id=function:_options_of
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_find_option
scope.3.kind=function
scope.3.startLine=11
scope.3.endLine=23
scope.3.semanticHash=298e03daef545a1d
scope.4.id=function:M.resolve_option_label
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=30
scope.4.semanticHash=a62b24c555449519
scope.5.id=function:M.resolve_option_by_id
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=40
scope.5.semanticHash=3d39f2bcd1a3e2cf
scope.6.id=function:<anonymous>
scope.6.kind=function
scope.6.startLine=36
scope.6.endLine=38
scope.6.semanticHash=02da81807b31bd0c
scope.7.id=function:M.resolve_option_label_by_id
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=50
scope.7.semanticHash=c7a999ebf33d2a34
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=43
scope.8.endLine=45
scope.8.semanticHash=02da81807b31bd0c
]]
