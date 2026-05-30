local runtime_ports = require("src.foundation.ports.runtime_ports")
local asset_total = require("src.rules.land.asset_total")

-- Custom player archive keys configured in the host editor: the host ranking
-- panels read and sort these values, so the Lua side only accumulates them.
local WIN_COUNT_KEY = 1001
local TOTAL_ASSETS_KEY = 1002

local leaderboard = {
  win_count_archive_key = WIN_COUNT_KEY,
  total_assets_archive_key = TOTAL_ASSETS_KEY,
  quit_reasons = {
    disconnect = true,
    manual_exit = true,
    crash = true,
  },
}

function leaderboard.is_quit_reason(reason)
  return leaderboard.quit_reasons[reason] == true
end

local function _add_archive_int(role_id, key, delta)
  if delta == 0 then
    return
  end
  local current = runtime_ports.get_archive_int(role_id, key)
  runtime_ports.set_archive_int(role_id, key, current + delta)
end

local function _winner_id_set(game)
  local ids = {}
  for _, winner in ipairs(game.winners or {}) do
    ids[winner.id] = true
  end
  return ids
end

-- Accumulate this game's contributions into the host archives once: each
-- winner gains one win (胜利榜); every player still in the game adds their
-- remaining total assets (富豪榜). Players who quit mid-game are excluded, and
-- the run is skipped entirely when the host has custom archives disabled.
-- TODO_HOST_INTEGRATION: the host quit event that marks player.quit_reason and
-- the game-finished trigger that calls settle are wired at the app boundary.
function leaderboard.settle(game)
  if game == nil or game.leaderboard_settled then
    return false
  end
  if not runtime_ports.archives_enabled() then
    return false
  end
  local winner_ids = _winner_id_set(game)
  for _, player in ipairs(game.players or {}) do
    if winner_ids[player.id] then
      _add_archive_int(player.id, WIN_COUNT_KEY, 1)
    end
    if not leaderboard.is_quit_reason(player.quit_reason) then
      _add_archive_int(player.id, TOTAL_ASSETS_KEY, asset_total.player_total(game, player))
    end
  end
  game.leaderboard_settled = true
  return true
end

return leaderboard

--[[ mutate4lua-manifest
version=2
projectHash=36057140be5a5dde
scope.0.id=chunk:src/app/host_integrations/leaderboard.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=66
scope.0.semanticHash=cd419d782e240f94
scope.0.lastMutatedAt=2026-05-29T14:57:49Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=21
scope.0.lastMutationKilled=21
scope.1.id=function:leaderboard.is_quit_reason:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=21
scope.1.semanticHash=76332a67ac7368c9
scope.1.lastMutatedAt=2026-05-29T14:57:49Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_add_archive_int:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=493c04bd22632d33
scope.2.lastMutatedAt=2026-05-29T14:57:49Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
]]
