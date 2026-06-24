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
projectHash=a674d029ec488eda
scope.0.id=chunk:src/ui/render/board_feedback/catalog.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=81
scope.0.semanticHash=ab248dfc89b2b70d
scope.1.id=function:_warn_invalid:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=fb8c7b6b50666b03
scope.2.id=function:_resolve_numeric_field:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=26
scope.2.semanticHash=ea5ed9f2b92486e5
scope.3.id=function:_resolve_bind_offset:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=36
scope.3.semanticHash=76718253a9d06229
scope.4.id=function:_resolve_cue:56
scope.4.kind=function
scope.4.startLine=56
scope.4.endLine=70
scope.4.semanticHash=84513270a5eca622
scope.5.id=function:catalog.get:72
scope.5.kind=function
scope.5.startLine=72
scope.5.endLine=78
scope.5.semanticHash=d7cf0939a119984d
]]
