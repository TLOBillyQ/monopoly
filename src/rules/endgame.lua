local event_kinds = require("src.config.gameplay.event_kinds")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local monopoly_event = require("src.foundation.events")
local asset_total = require("src.rules.land.asset_total")
local bankruptcy = require("src.rules.endgame.bankruptcy")
local timing = require("src.config.gameplay.timing")

local M = {}

M.eliminate = bankruptcy.eliminate
M._call_life_die = bankruptcy._call_life_die
M._resolve_life_component = bankruptcy._resolve_life_component
M._try_call_life_die = bankruptcy._try_call_life_die
M._resolve_bankruptcy_text = bankruptcy._resolve_bankruptcy_text

local function _total_assets(game, player)
  return asset_total.player_total(game, player)
end

local function _winner_names(list)
  local names = {}
  assert(list ~= nil, "missing winner list")
  for _, player in ipairs(list) do
    table.insert(names, player.name)
  end
  return table.concat(names, "、")
end

local function _assign_winner_fields(game, winners)
  game.winners = winners
  if #winners == 1 then
    game.winner = winners[1]
  else
    game.winner = nil
  end
  local names = _winner_names(winners)
  game.winner_names = names
  return names
end

local function _publish_victory(game, message)
  assert(message ~= nil, "missing victory message")
  event_feed.publish(game, {
    kind = event_kinds.victory,
    text = message .. game.winner_names,
  })
end

local function _record_winner_progress(game, winners)
  local winner_ids = {}
  for _, player in ipairs(winners) do
    winner_ids[player.id] = true
    achievement_progress.game_won(game, player)
  end
  return winner_ids
end

local function _emit_game_finished(winners, winner_ids, names, message)
  monopoly_event.emit(monopoly_event.game.finished, {
    winners = winners,
    winner_ids = winner_ids,
    winner_names = names,
    message = message,
  })
end

local function _apply_winners(game, winners, message)
  local names = _assign_winner_fields(game, winners)
  _publish_victory(game, message)
  local winner_ids = _record_winner_progress(game, winners)
  _emit_game_finished(winners, winner_ids, names, message)
  game.finished = true
  return true
end

local function _positive_limit(value)
  if value == nil or value <= 0 then
    return nil
  end
  return value
end

local function _elapsed_game_time(game)
  if game.game_time_seconds ~= nil then return game.game_time_seconds end
  if game.elapsed_game_seconds ~= nil then return game.elapsed_game_seconds end
  if game.elapsed_seconds ~= nil then return game.elapsed_seconds end
  return game.current_time
end

local function _game_time_reached(game)
  local limit = _positive_limit(timing.game_time_limit_seconds)
  if limit == nil then
    return false
  end
  local elapsed = _elapsed_game_time(game)
  return elapsed ~= nil and elapsed >= limit
end

local function _turn_limit_reached(game)
  local turn_limit = _positive_limit(timing.turn_limit)
  if turn_limit == nil then
    return false
  end
  local turn_count = game.turn and game.turn.turn_count or nil
  return turn_count ~= nil and turn_count >= turn_limit
end

local function _apply_asset_winners(game, alive)
  if #alive == 0 then
    return _apply_winners(game, {}, "游戏结束，无人生还")
  end
  local winners = {}
  local best = nil
  for _, player in ipairs(alive) do
    local assets = _total_assets(game, player)
    if best == nil or assets > best then
      best = assets
      winners = { player }
    elseif assets == best then
      table.insert(winners, player)
    end
  end
  return _apply_winners(game, winners, "游戏结束，时间到，胜者:")
end

function M.check_victory(self)
  if self.finished then
    return true
  end
  local alive = self:alive_players()
  if _game_time_reached(self) or _turn_limit_reached(self) then
    return _apply_asset_winners(self, alive)
  end
  if #alive <= 1 then
    if #alive == 1 then
      return _apply_winners(self, { alive[1] }, "游戏结束，胜者:")
    end
    return _apply_winners(self, {}, "游戏结束，无人生还")
  end
  return false
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=03169323d3115905
scope.0.id=chunk:src/rules/endgame.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=145
scope.0.semanticHash=46aa69f24db06ebc
scope.0.lastMutatedAt=2026-07-07T04:14:41Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=25
scope.0.lastMutationKilled=25
scope.1.id=function:_total_assets:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=19
scope.1.semanticHash=8acd1922ba0b1360
scope.1.lastMutatedAt=2026-07-07T04:14:41Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_assign_winner_fields:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=40
scope.2.semanticHash=3117be9b8b41785f
scope.2.lastMutatedAt=2026-07-07T04:14:41Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_publish_victory:42
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=48
scope.3.semanticHash=ab8226a33e99dcdf
scope.3.lastMutatedAt=2026-07-07T04:14:41Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=2
scope.3.lastMutationKilled=2
scope.4.id=function:_emit_game_finished:59
scope.4.kind=function
scope.4.startLine=59
scope.4.endLine=66
scope.4.semanticHash=988561ed830138e0
scope.4.lastMutatedAt=2026-07-07T04:14:41Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_apply_winners:68
scope.5.kind=function
scope.5.startLine=68
scope.5.endLine=75
scope.5.semanticHash=bbadb43146c73b8c
scope.5.lastMutatedAt=2026-07-07T04:14:41Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:_positive_limit:77
scope.6.kind=function
scope.6.startLine=77
scope.6.endLine=82
scope.6.semanticHash=994168dee499d516
scope.6.lastMutatedAt=2026-07-07T04:14:41Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:_elapsed_game_time:84
scope.7.kind=function
scope.7.startLine=84
scope.7.endLine=89
scope.7.semanticHash=a2b940c1aed2eb83
scope.7.lastMutatedAt=2026-07-07T04:14:41Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:_game_time_reached:91
scope.8.kind=function
scope.8.startLine=91
scope.8.endLine=98
scope.8.semanticHash=4e15896892e9ca4d
scope.8.lastMutatedAt=2026-07-07T04:14:41Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=7
scope.9.id=function:_turn_limit_reached:100
scope.9.kind=function
scope.9.startLine=100
scope.9.endLine=107
scope.9.semanticHash=9ddd887506769837
scope.9.lastMutatedAt=2026-07-07T04:14:41Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=8
scope.9.lastMutationKilled=8
scope.10.id=function:M.check_victory:127
scope.10.kind=function
scope.10.startLine=127
scope.10.endLine=142
scope.10.semanticHash=1fd3f2945e3bbcd0
scope.10.lastMutatedAt=2026-07-07T04:14:41Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=13
scope.10.lastMutationKilled=13
]]
