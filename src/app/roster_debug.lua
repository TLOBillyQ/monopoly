local debug_flags = require("src.config.gameplay.debug_flags")

local M = {}

local function _should_build_debug_auto_players(build_mode)
  return build_mode ~= "release"
    and debug_flags.debug_auto_non_primary == true
end

local function _add_debug_auto_player(auto_players, entry)
  if entry == nil or entry.role_id == nil then
    return auto_players
  end
  auto_players = auto_players or {}
  auto_players[entry.role_id] = true
  return auto_players
end

function M.build_auto_players(role_roster, build_mode)
  if not _should_build_debug_auto_players(build_mode) then
    return nil
  end
  local auto_players = nil
  for i = 2, #role_roster do
    auto_players = _add_debug_auto_player(auto_players, role_roster[i])
  end
  return auto_players
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=2ec3d359f0acd273
scope.0.id=chunk:src/app/roster_debug.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=c25a1d8aec124a22
scope.0.lastMutatedAt=2026-06-24T20:07:26Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:_should_build_debug_auto_players:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=8
scope.1.semanticHash=75669ab3182e90df
scope.1.lastMutatedAt=2026-06-24T20:07:26Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:_add_debug_auto_player:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=17
scope.2.semanticHash=a9041be05578d806
scope.2.lastMutatedAt=2026-06-24T20:07:26Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
]]
