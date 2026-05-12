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
