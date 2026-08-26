local logger = require("src.foundation.log")

local move_anim_debug = {}

function move_anim_debug.enabled()
  return logger.is_anim_debug_enabled()
end

function move_anim_debug.log(...)
  if not move_anim_debug.enabled() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

return move_anim_debug

--[[ mutate4lua-manifest
version=4
projectHash=fb53fb88261e6e7e
scope.0.id=chunk:src/foundation/move_anim_debug.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=16a6efb98178e106
scope.1.id=function:move_anim_debug.enabled
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=04a3b0c01baa0aa1
scope.2.id=function:move_anim_debug.log
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=14
scope.2.semanticHash=76a28ee870bd82c2
]]
