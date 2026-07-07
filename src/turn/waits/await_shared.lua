local dirty_tracker = require("src.state.dirty_tracker")

local shared = {}

shared.WAIT = { wait = true }
shared.DONE = { done = true }

function shared.unpack_next(args)
  args = args or {}
  return args.next_state, args.next_args
end

shared.mark_dirty = dirty_tracker.mark_turn

return shared

--[[ mutate4lua-manifest
version=2
projectHash=7e039f7bd8d7df96
scope.0.id=chunk:src/turn/waits/await_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=f1eea983715d36a8
scope.0.lastMutatedAt=2026-07-07T02:12:26Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:shared.unpack_next:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=359ac1e95545f4b3
scope.1.lastMutatedAt=2026-07-07T02:12:26Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
]]
