local dirty_tracker = require("src.state.dirty_tracker")

local deferred_dirty = {}

deferred_dirty.new_bucket = dirty_tracker.new

deferred_dirty.merge_into = dirty_tracker.merge_into

function deferred_dirty.reset(hold)
  hold.deferred_dirty = deferred_dirty.new_bucket()
end

function deferred_dirty.defer(hold, dirty)
  deferred_dirty.merge_into(hold.deferred_dirty, dirty)
  return hold.deferred_dirty
end

return deferred_dirty

--[[ mutate4lua-manifest
version=4
projectHash=4a5c11da41708ff9
scope.0.id=chunk:src/state/visual_hold/deferred_dirty.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=19
scope.0.semanticHash=6507011cf383e89f
scope.1.id=function:deferred_dirty.reset
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=6fdda16a71380564
scope.2.id=function:deferred_dirty.defer
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=16
scope.2.semanticHash=c555b841ba4673e6
]]
