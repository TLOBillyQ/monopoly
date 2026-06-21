local rent_resolver = require("src.rules.land.rent_resolver")
local achievement_progress = require("src.rules.ports.achievement_progress")

local achievement_hooks = {}

function achievement_hooks.record_contiguous_if_reached(game, player, tile)
  local board = game and game.board or nil
  if not (board and tile and tile.id ~= nil) then
    return
  end
  local tile_index = board:index_of_tile_id(tile.id)
  if tile_index == nil then
    return
  end
  local count = rent_resolver.contiguous_count(game, board, tile_index, player.id)
  if count >= 3 then
    achievement_progress.contiguous_lands(game, player)
  end
end

return achievement_hooks

--[[ mutate4lua-manifest
version=2
projectHash=99469cd9addb57c9
scope.0.id=chunk:src/rules/land/achievement_hooks.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=22
scope.0.semanticHash=9428b0d98a625b3f
scope.0.lastMutatedAt=2026-06-21T06:23:47Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:achievement_hooks.record_contiguous_if_reached:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=19
scope.1.semanticHash=e314034e94afe5e6
scope.1.lastMutatedAt=2026-06-21T06:23:47Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=11
scope.1.lastMutationKilled=11
]]
