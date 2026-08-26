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
version=4
projectHash=ff4ae46a7b841633
scope.0.id=chunk:src/ui/render/board/visual_sync_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=124af6df435dad43
scope.1.id=function:visual_sync_shared.deps
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=616a2ca60599c94f
scope.2.id=function:visual_sync_shared.resolve_board
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=10
scope.2.semanticHash=93c839897afe61e5
scope.3.id=function:visual_sync_shared.resolve_scene
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=616a2ca60599c94f
]]
