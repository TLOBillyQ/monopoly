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

local function _accumulate_player(game, player, winner_ids)
  if winner_ids[player.id] then
    _add_archive_int(player.id, WIN_COUNT_KEY, 1)
  end
  if not leaderboard.is_quit_reason(player.quit_reason) then
    _add_archive_int(player.id, TOTAL_ASSETS_KEY, asset_total.player_total(game, player))
  end
end

-- Accumulate this game's contributions into the host archives once: each
-- winner gains one win (胜利榜); every player still in the game adds their
-- remaining total assets (富豪榜). Players who quit mid-game are excluded, and
-- the run is skipped entirely when the host has custom archives disabled.
-- 结算触发与中途退出标记由 app 边界 leaderboard_settlement 接线
-- (gm.finished → settle;宿主角色退出触发器 → quit_reason)。
-- settle 前置守卫:游戏缺失/已结算过,或宿主关闭了自定义档案,整次结算跳过。
local function _should_settle(game)
  if game == nil or game.leaderboard_settled then
    return false
  end
  return runtime_ports.archives_enabled()
end

function leaderboard.settle(game)
  if not _should_settle(game) then
    return false
  end
  local winner_ids = _winner_id_set(game)
  for _, player in ipairs(game.players or {}) do
    _accumulate_player(game, player, winner_ids)
  end
  game.leaderboard_settled = true
  return true
end

return leaderboard

--[[ mutate4lua-manifest
version=4
projectHash=d5cd79bec6ec486a
scope.0.id=chunk:src/app/host_integrations/leaderboard.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=6a7cb10012721117
scope.1.id=function:leaderboard.is_quit_reason
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=21
scope.1.semanticHash=f6f9846e02e2a0a4
scope.2.id=function:_add_archive_int
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=29
scope.2.semanticHash=277b96fa3c3e5944
scope.3.id=function:_winner_id_set
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=37
scope.3.semanticHash=d2ec718237f1e202
scope.4.id=function:_accumulate_player
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=46
scope.4.semanticHash=621352fcde8c33f9
scope.5.id=function:_should_settle
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=60
scope.5.semanticHash=0f36981c3b913c03
scope.6.id=function:leaderboard.settle
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=72
scope.6.semanticHash=251ec47a835b69d9
]]
