local effect_track = require("src.ui.render.support.effect_track")
local impl = require("src.state.visual_hold")
impl.set_post_release_hook(function() effect_track.await_all() end)
return impl

--[[ mutate4lua-manifest
version=4
projectHash=4c48b349b19fb24d
scope.0.id=chunk:src/ui/visual_hold.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=5
scope.0.semanticHash=fc86e8c28acf273b
scope.1.id=function:<anonymous>
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=3
scope.1.semanticHash=fa86f4a0c97ffab8
]]
