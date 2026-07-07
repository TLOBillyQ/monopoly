local visual_sync_shared = {}

function visual_sync_shared.deps(state)
  return state and state.presentation_runtime or nil
end

function visual_sync_shared.resolve_board(state)
  local game = state and state.game or nil
  return game and game.board or nil
end

function visual_sync_shared.resolve_scene(state)
  return state and state.board_scene or nil
end

return visual_sync_shared

--[[ mutate4lua-manifest
version=2
projectHash=edf65ccc819a67ac
scope.0.id=chunk:src/ui/render/board/visual_sync_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=476af5ee87af66ae
scope.1.id=function:visual_sync_shared.deps:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=b8f790d7696eb9d4
scope.1.lastMutatedAt=2026-07-07T02:48:10Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:visual_sync_shared.resolve_board:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=10
scope.2.semanticHash=caba96cb3936f37b
scope.2.lastMutatedAt=2026-07-07T02:48:10Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:visual_sync_shared.resolve_scene:12
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=849f0cac061b7293
scope.3.lastMutatedAt=2026-07-07T02:48:10Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
]]
