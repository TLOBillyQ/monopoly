local constants = require("src.config.content.constants")
local tables = require("src.foundation.tables")
local dirty_tracker = require("src.state.dirty_tracker")

local common = {}

common.constants = constants

function common.player_status_table(player)
  player.status = player.status or {}
  return player.status
end

common.normalize_currency = tables.normalize_currency

function common.mark_players(game)
  dirty_tracker.mark(game.dirty, "players")
end

return common

--[[ mutate4lua-manifest
version=2
projectHash=044540f7587a1225
scope.0.id=chunk:src/player/actions/state_common.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=4d214d6d5170a5b3
scope.0.lastMutatedAt=2026-07-07T03:27:31Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:common.player_status_table:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=12
scope.1.semanticHash=db12c7262fd0554d
scope.1.lastMutatedAt=2026-07-07T03:27:31Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:common.mark_players:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=9a7052a2e6d89adb
scope.2.lastMutatedAt=2026-07-07T03:27:31Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
]]
