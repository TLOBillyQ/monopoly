local constants = require("src.config.content.constants")
local dirty_tracker = require("src.state.dirty_tracker")

local common = {}

common.constants = constants

function common.player_status_table(player)
  player.status = player.status or {}
  return player.status
end

function common.mark_players(game)
  dirty_tracker.mark(game.dirty, "players")
end

return common

--[[ mutate4lua-manifest
version=4
projectHash=9029716faa1e1ef9
scope.0.id=chunk:src/player/actions/state_common.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=18
scope.0.semanticHash=7056d483ec69e32b
scope.1.id=function:common.player_status_table
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=db8a9d69e6ae7b6a
scope.2.id=function:common.mark_players
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=15
scope.2.semanticHash=84b996fd1b689e65
]]
