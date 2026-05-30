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
version=2
projectHash=4b447c0af093a0b1
scope.0.id=chunk:src/ui/render/board/events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=25
scope.0.semanticHash=6aab448d9c5ed509
scope.1.id=function:_sync_single_tile:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=12
scope.1.semanticHash=e46a26190a5a25b8
scope.2.id=function:M.on_tile_upgraded:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=eac3293bcd68bf79
scope.3.id=function:M.on_tile_owner_changed:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=6863e59383e113df
]]
