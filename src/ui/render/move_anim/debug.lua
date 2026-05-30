local move_anim_debug = require("src.foundation.move_anim_debug")

local debug_mod = {}

debug_mod.enabled = move_anim_debug.enabled
debug_mod.debug_log = move_anim_debug.log

return debug_mod

--[[ mutate4lua-manifest
version=2
projectHash=e0d998775aef59b7
scope.0.id=chunk:src/ui/render/move_anim/debug.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=9a8397e3134de546
scope.0.lastMutatedAt=2026-05-28T15:24:56Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=1
scope.0.lastMutationKilled=1
]]
