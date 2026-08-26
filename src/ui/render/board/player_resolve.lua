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
version=4
projectHash=8457545be2cff913
scope.0.id=chunk:src/ui/render/board/player_resolve.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=f31cea15481564e5
scope.1.id=function:M.resolve_player_id
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=a055eae117c85c13
scope.2.id=function:M.resolve_active_player_base
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=13
scope.2.semanticHash=d540d9fae0ff3ba8
]]
