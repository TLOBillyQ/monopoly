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
projectHash=99919342d5e39fac
scope.0.id=chunk:src/rules/endgame.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=247
scope.0.semanticHash=24740057e23502fe
scope.1.id=function:_try_pcall:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=20
scope.1.semanticHash=6f89766602c9c795
scope.2.id=function:_call_role_die:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=27
scope.2.semanticHash=dc1fa054e243ccd3
scope.3.id=function:_resolve_life_component:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=38
scope.3.semanticHash=8d0d76420bc2a288
scope.4.id=function:_call_life_die:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=47
scope.4.semanticHash=f41e4ce492d87dc5
scope.5.id=function:_try_call_life_die:49
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=57
scope.5.semanticHash=a8b24d74738db21d
scope.6.id=function:_resolve_bankruptcy_text:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=64
scope.6.semanticHash=d5f7e3b4fb5f8d21
scope.7.id=function:_push_bankruptcy_popup:66
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=80
scope.7.semanticHash=e16d252acd70fcc0
]]
