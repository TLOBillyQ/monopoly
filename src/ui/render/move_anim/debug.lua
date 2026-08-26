local move_anim_debug = require("src.foundation.move_anim_debug")

local debug_mod = {}

debug_mod.enabled = move_anim_debug.enabled
debug_mod.debug_log = move_anim_debug.log

return debug_mod

--[[ mutate4lua-manifest
version=4
projectHash=83fddaef77c10d5a
scope.0.id=chunk:src/ui/render/move_anim/debug.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=d95839478579d4bd
]]
