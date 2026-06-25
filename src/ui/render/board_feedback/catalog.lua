local runtime_assets = require("src.config.runtime_assets")
local runtime_refs = require("src.config.content.runtime_refs")

local catalog = {}

function catalog.get(cue_name, payload)
  local cue = runtime_assets.board_feedback_cue(cue_name, payload, {
    refs = runtime_refs,
  })
  if cue.ok ~= true then
    return nil
  end
  return cue
end

return catalog

--[[ mutate4lua-manifest
version=2
projectHash=6a60b5b4e3dc2c6a
scope.0.id=chunk:src/ui/render/board_feedback/catalog.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=98932ace7750950c
scope.0.lastMutatedAt=2026-06-24T20:11:43Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:catalog.get:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=c4d0fdc09c9fb7a3
scope.1.lastMutatedAt=2026-06-24T20:11:43Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
]]
