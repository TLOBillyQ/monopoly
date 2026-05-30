local debug_flags = require("src.config.gameplay.debug_flags")
local logger = require("src.foundation.log")

local move_anim_debug = {}

function move_anim_debug.enabled()
  return logger.is_anim_debug_enabled() or debug_flags.move_anim_debug_log_enabled == true
end

function move_anim_debug.log(...)
  if not move_anim_debug.enabled() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

return move_anim_debug

--[[ mutate4lua-manifest
version=2
projectHash=e8cb957cda79fab3
scope.0.id=chunk:src/foundation/move_anim_debug.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=18
scope.0.semanticHash=36ef5f82a5aac602
scope.0.lastMutatedAt=2026-05-28T15:20:00Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:move_anim_debug.enabled:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=7829e88f0e28a7f6
scope.1.lastMutatedAt=2026-05-28T15:20:00Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:move_anim_debug.log:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=d2defe22f1e998b0
scope.2.lastMutatedAt=2026-05-28T15:20:00Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
]]
