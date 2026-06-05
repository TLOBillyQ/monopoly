local number_utils = require("src.foundation.number")

local actions = {}

function actions.kind(action)
  if type(action) == "table" then
    return action.type or action.action
  end
  return action
end

function actions.slot_index(action)
  if type(action) == "table" then
    return action.slot_index or action.index or action.slot or 1
  end
  return 1
end

function actions.numeric_slot(action)
  return number_utils.to_integer(action)
end

return actions

--[[ mutate4lua-manifest
version=2
projectHash=522af47967b9df85
scope.0.id=chunk:src/ui/coord/skin_panel_actions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=24
scope.0.semanticHash=aebd44104127896b
scope.0.lastMutatedAt=2026-06-05T07:32:04Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
scope.1.id=function:actions.kind:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=780fea0cc74c5007
scope.1.lastMutatedAt=2026-06-05T07:32:04Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:actions.slot_index:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=4ad3201cd113fe75
scope.2.lastMutatedAt=2026-06-05T07:32:04Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=8
scope.2.lastMutationKilled=8
scope.3.id=function:actions.numeric_slot:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=c248edb2bb670c06
scope.3.lastMutatedAt=2026-06-05T07:32:04Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
]]
