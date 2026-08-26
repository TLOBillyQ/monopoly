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
version=4
projectHash=e8a24f501915a22c
scope.0.id=chunk:src/ui/render/board_feedback/catalog.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=503e94776220d131
scope.1.id=function:catalog.get
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=bf027eb8c6436799
]]
