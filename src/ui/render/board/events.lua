local visual_sync = require("src.ui.render.board.visual_sync")

local M = {}

function M.on_tile_upgraded(state, tile_id, level)
  if tile_id == nil then
    return false
  end
  return visual_sync.sync_many(state, {
    tile_ids = { tile_id },
  })
end

function M.on_tile_owner_changed(state, tile_id, owner_id)
  if tile_id == nil then
    return false
  end
  return visual_sync.sync_many(state, {
    tile_ids = { tile_id },
  })
end

function M.sync_many(state, payload)
  return visual_sync.sync_many(state, payload)
end

return M
