local effect_track = require("src.ui.render.support.effect_track")
local impl = require("src.state.visual_hold")
impl.set_post_release_hook(function() effect_track.await_all() end)
return impl

--[[ mutate4lua-manifest
version=2
projectHash=19e140c0e5101b05
scope.0.id=chunk:src/ui/visual_hold.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=5
scope.0.semanticHash=2498f358e353f55f
scope.1.id=function:anonymous@3:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=3
scope.1.semanticHash=1d0251d0e7a7d4a1
]]
