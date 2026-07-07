local M = {}

function M.resolve_player_id(player, i)
  return assert(player.id, "missing player id: " .. tostring(i))
end

function M.resolve_active_player_base(state, player, i)
  local idx = assert(player.position, "missing player position: " .. tostring(i))
  assert(state.tile_positions ~= nil, "missing tile_positions")
  local base = assert(state.tile_positions[idx], "missing tile_position: " .. tostring(idx))
  local pid = M.resolve_player_id(player, i)
  return idx, base, pid
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=58a1da21844bb59a
scope.0.id=chunk:src/ui/render/board/player_resolve.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=2b8b8eadbf207071
scope.1.id=function:M.resolve_player_id:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=ccecb587b9d5bfe7
scope.1.lastMutatedAt=2026-07-07T02:15:06Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:M.resolve_active_player_base:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=13
scope.2.semanticHash=3d1a32255365cd01
scope.2.lastMutatedAt=2026-07-07T02:15:06Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
]]
