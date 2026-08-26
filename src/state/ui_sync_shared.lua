local shared = {}
local _cached_env = {}

local function _turn_countdown_only(dirty)
  return dirty ~= nil and dirty.turn_countdown == true
end

local function _has_other_dirty(dirty)
  return dirty.players or dirty.board_tiles or dirty.turn or dirty.market or dirty.ui
end

local function _has_inventory_dirty(dirty)
  return dirty.inventory == true
end

function shared.is_only_turn_countdown(dirty)
  if not _turn_countdown_only(dirty) then
    return false
  end
  if _has_other_dirty(dirty) then
    return false
  end
  return not _has_inventory_dirty(dirty)
end

local function _game_field(game, key)
  return game and game[key] or nil
end

local function _winner_name(game, winner)
  return game and (game.winner_names or (winner and winner.name)) or nil
end

function shared.build_ui_env(state, game)
  local winner = _game_field(game, "winner")
  local winner_name = _winner_name(game, winner)
  _cached_env.game = game
  _cached_env.ui_state = state
  _cached_env.last_turn = _game_field(game, "last_turn")
  _cached_env.finished = _game_field(game, "finished")
  _cached_env.winner_name = winner_name
  return _cached_env
end

return shared

--[[ mutate4lua-manifest
version=4
projectHash=a0f1be1e0ad56199
scope.0.id=chunk:src/state/ui_sync_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=9dc8ce3a2ef879c7
scope.1.id=function:_turn_countdown_only
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=be8994585243633b
scope.2.id=function:_has_other_dirty
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=03b6b2dd2c4e56d4
scope.3.id=function:_has_inventory_dirty
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=14
scope.3.semanticHash=04dff2c832cce8d0
scope.4.id=function:shared.is_only_turn_countdown
scope.4.kind=function
scope.4.startLine=16
scope.4.endLine=24
scope.4.semanticHash=22974b7c3ae38e83
scope.5.id=function:_game_field
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=28
scope.5.semanticHash=cd6b189045fad21d
scope.6.id=function:_winner_name
scope.6.kind=function
scope.6.startLine=30
scope.6.endLine=32
scope.6.semanticHash=5ff88d0b86260553
scope.7.id=function:shared.build_ui_env
scope.7.kind=function
scope.7.startLine=34
scope.7.endLine=43
scope.7.semanticHash=120f046046b07f89
]]
