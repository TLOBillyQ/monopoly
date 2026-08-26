local event_kinds = require("src.config.gameplay.event_kinds")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local monopoly_event = require("src.foundation.events")
local asset_total = require("src.rules.land.asset_total")
local bankruptcy = require("src.rules.endgame.bankruptcy")
local timing = require("src.config.gameplay.timing")

local M = {}

M.eliminate = bankruptcy.eliminate
M._try_call_life_die = bankruptcy._try_call_life_die
M._resolve_bankruptcy_text = bankruptcy._resolve_bankruptcy_text

local function _total_assets(game, player)
  return asset_total.player_total(game, player)
end

local function _winner_names(list)
  local names = {}
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

local function _record_candidate(winners, best, player, assets)
  if best == nil or assets > best then
    return assets, { player }
  end
  if assets == best then
    table.insert(winners, player)
  end
  return best, winners
end

local function _apply_asset_winners(game, alive)
  if #alive == 0 then
    return _apply_winners(game, {}, "游戏结束，无人生还")
  end
  local winners = {}
  local best = nil
  for _, player in ipairs(alive) do
    best, winners = _record_candidate(winners, best, player, _total_assets(game, player))
  end
  return _apply_winners(game, winners, "游戏结束，时间到，胜者:")
end

-- tick 层的门卫谓词:时钟没到点不必每帧跑完整 check_victory(省掉每帧 alive_players 分配)。
M.game_time_reached = _game_time_reached

local function _victory_by_alive_count(game, alive)
  if #alive == 1 then
    return _apply_winners(game, { alive[1] }, "游戏结束，胜者:")
  end
  return _apply_winners(game, {}, "游戏结束，无人生还")
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
    return _victory_by_alive_count(self, alive)
  end
  return false
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=9e8e6e534a0536bb
scope.0.id=chunk:src/rules/endgame.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=152
scope.0.semanticHash=3ab375d6d276dbf0
scope.1.id=function:_total_assets
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=aba9250a8c6b104f
scope.2.id=function:_winner_names
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=25
scope.2.semanticHash=380ebff51c94f65f
scope.3.id=function:_assign_winner_fields
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=37
scope.3.semanticHash=0cee797f9d280472
scope.4.id=function:_publish_victory
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=44
scope.4.semanticHash=87b8eff829b4ea90
scope.5.id=function:_record_winner_progress
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=53
scope.5.semanticHash=9dde682f965991d9
scope.6.id=function:_emit_game_finished
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=62
scope.6.semanticHash=cc9f9ca4aa196004
scope.7.id=function:_apply_winners
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=71
scope.7.semanticHash=80192af98990a645
scope.8.id=function:_positive_limit
scope.8.kind=function
scope.8.startLine=73
scope.8.endLine=78
scope.8.semanticHash=48e38461da3911a2
scope.9.id=function:_elapsed_game_time
scope.9.kind=function
scope.9.startLine=80
scope.9.endLine=85
scope.9.semanticHash=04c41c20fb90c418
scope.10.id=function:_game_time_reached
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=94
scope.10.semanticHash=f0e7ae12e52589f6
scope.11.id=function:_turn_limit_reached
scope.11.kind=function
scope.11.startLine=96
scope.11.endLine=103
scope.11.semanticHash=c2bf8b6604790e9a
scope.12.id=function:_record_candidate
scope.12.kind=function
scope.12.startLine=105
scope.12.endLine=113
scope.12.semanticHash=91d9b43e9c83e52e
scope.13.id=function:_apply_asset_winners
scope.13.kind=function
scope.13.startLine=115
scope.13.endLine=125
scope.13.semanticHash=ac730a19b56ee06f
scope.14.id=function:_victory_by_alive_count
scope.14.kind=function
scope.14.startLine=130
scope.14.endLine=135
scope.14.semanticHash=aab14103e677df95
scope.15.id=function:M.check_victory
scope.15.kind=function
scope.15.startLine=137
scope.15.endLine=149
scope.15.semanticHash=6931582c22a95856
]]
