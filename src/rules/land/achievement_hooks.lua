local rent_resolver = require("src.rules.land.rent_resolver")
local achievement_progress = require("src.rules.ports.achievement_progress")

local achievement_hooks = {}

local function _board_of(game)
  return game and game.board or nil
end

local function _tile_index_of(board, tile)
  if board and tile and tile.id ~= nil then
    return board:index_of_tile_id(tile.id)
  end
  return nil
end

function achievement_hooks.record_contiguous_if_reached(game, player, tile)
  local board = _board_of(game)
  local tile_index = _tile_index_of(board, tile)
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
version=4
projectHash=7de5d987393674df
scope.0.id=chunk:src/rules/land/achievement_hooks.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=8359e87c291977e1
scope.1.id=function:_board_of
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=616a2ca60599c94f
scope.2.id=function:_tile_index_of
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=23dfc848d88b0845
scope.3.id=function:achievement_hooks.record_contiguous_if_reached
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=27
scope.3.semanticHash=2553a0886bd97b97
]]
