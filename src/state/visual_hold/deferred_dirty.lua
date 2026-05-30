local dirty_tracker = require("src.state.dirty_tracker")

local deferred_dirty = {}

deferred_dirty.new_bucket = dirty_tracker.new

function deferred_dirty.ensure_inventory_ids(hold)
  if type(hold.deferred_dirty) ~= "table" then
    hold.deferred_dirty = deferred_dirty.new_bucket()
  end
  dirty_tracker.ensure_inventory_ids(hold.deferred_dirty)
end

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
version=2
projectHash=ae5a4be28a07bcff
scope.0.id=chunk:src/state/visual_hold/deferred_dirty.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=26
scope.0.semanticHash=eca4d0ae187d5160
scope.1.id=function:deferred_dirty.ensure_inventory_ids:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=df618f1df12b215d
scope.2.id=function:deferred_dirty.reset:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=e595bc414a3d58a7
scope.3.id=function:deferred_dirty.defer:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=23
scope.3.semanticHash=c33c4631f690864c
]]
