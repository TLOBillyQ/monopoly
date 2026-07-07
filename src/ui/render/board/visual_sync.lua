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
projectHash=9db973a80882c1c9
scope.0.id=chunk:src/ui/render/board/visual_sync.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=12
scope.0.semanticHash=c94c36409e5469ad
scope.0.lastMutatedAt=2026-07-07T02:47:41Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
]]
