local service = require("src.turn.deadlines.service")
local force_skip = require("src.turn.deadlines.force_skip")
local choice_resolution = require("src.turn.deadlines.choice_resolution")

local M = {
  start = service.start,
  cancel = service.cancel,
  peek = service.peek,
  tick = service.tick,
  is_active = service.is_active,
}

force_skip.install(M)
choice_resolution.install(M)

return M

--[[ mutate4lua-manifest
version=2
projectHash=a75e54fdd9e93484
scope.0.id=chunk:src/turn/deadlines.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=d784c9285f714812
]]
