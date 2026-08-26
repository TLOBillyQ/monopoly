local visual_sync = require("src.ui.render.board.visual_sync")

local M = {}

local function _sync_single_tile(state, tile_id)
  if tile_id == nil then
    return false
  end
  return visual_sync.sync_many(state, {
    tile_ids = { tile_id },
  })
end

function M.on_tile_upgraded(state, tile_id, _)
  return _sync_single_tile(state, tile_id)
end

function M.on_tile_owner_changed(state, tile_id, _)
  return _sync_single_tile(state, tile_id)
end

M.sync_many = visual_sync.sync_many

return M

--[[ mutate4lua-manifest
version=4
projectHash=328d9b893939d32b
scope.0.id=chunk:src/ui/render/board/events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=c0a5f33e0c818423
scope.1.id=function:_sync_single_tile
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=12
scope.1.semanticHash=ce125ca5476e25df
scope.2.id=function:M.on_tile_upgraded
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=3c26bf1ea8e4b724
scope.3.id=function:M.on_tile_owner_changed
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=3c26bf1ea8e4b724
]]
