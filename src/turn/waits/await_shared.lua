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
version=4
projectHash=700cc6beaad0614f
scope.0.id=chunk:src/turn/waits/await_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=fc8f24ab7b5b68e2
scope.1.id=function:shared.unpack_next
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=b8940f6f0b712e78
]]
