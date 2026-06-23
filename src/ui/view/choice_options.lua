local M = {}

function M.resolve_option_id(option)
  return type(option) == "table" and option.id or option
end

local function _find_option(choice, predicate)
  local options = choice and choice.options or nil
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
version=2
projectHash=1fad31a35ec1529f
scope.0.id=chunk:src/ui/view/choice_options.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=49
scope.0.semanticHash=272653e9d4ca0d88
scope.0.lastMutatedAt=2026-06-23T04:27:22Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
scope.1.id=function:M.resolve_option_id:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=667ddf720635612a
scope.1.lastMutatedAt=2026-06-23T04:27:22Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:M.resolve_option_label:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=26
scope.2.semanticHash=a7e22f4fd8f101bf
scope.2.lastMutatedAt=2026-06-23T04:27:22Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=10
scope.2.lastMutationKilled=10
scope.3.id=function:anonymous@32:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=34
scope.3.semanticHash=b63d73f7e2597557
scope.3.lastMutatedAt=2026-06-23T04:27:22Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=no_sites
scope.3.lastMutationSites=0
scope.3.lastMutationKilled=0
scope.4.id=function:M.resolve_option_by_id:28
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=36
scope.4.semanticHash=86f6a693a66601b3
scope.4.lastMutatedAt=2026-06-23T04:27:22Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:anonymous@39:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=41
scope.5.semanticHash=b63d73f7e2597557
scope.5.lastMutatedAt=2026-06-23T04:27:22Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=no_sites
scope.5.lastMutationSites=0
scope.5.lastMutationKilled=0
scope.6.id=function:M.resolve_option_label_by_id:38
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=46
scope.6.semanticHash=ddfd0cdca68901fe
scope.6.lastMutatedAt=2026-06-23T04:27:22Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=8
]]
