local tile_sync = require("src.ui.render.board.visual_sync_tile")
local overlay_sync = require("src.ui.render.board.visual_sync_overlay")
local batch_sync = require("src.ui.render.board.visual_sync_batch")

local visual_sync = {}

visual_sync.sync_tile_visual = tile_sync.sync_tile_visual
visual_sync.sync_overlay_visual = overlay_sync.sync_overlay_visual
visual_sync.sync_many = batch_sync.sync_many

return visual_sync

--[[ mutate4lua-manifest
version=2
projectHash=ea8bbfbe8fa0a066
scope.0.id=chunk:src/ui/render/board/visual_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=12
scope.0.semanticHash=c94c36409e5469ad
]]
