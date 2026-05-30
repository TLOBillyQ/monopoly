local shared = {}
local _cached_env = {}

function shared.is_only_turn_countdown(dirty)
  if not dirty or dirty.turn_countdown ~= true then
    return false
  end
  if dirty.players or dirty.board_tiles or dirty.turn or dirty.market or dirty.ui then
    return false
  end
  if dirty.inventory_ids and next(dirty.inventory_ids) ~= nil then
    return false
  end
  return true
end

function shared.build_ui_env(state, game)
  local winner = game and game.winner or nil
  local winner_name = game and (game.winner_names or (winner and winner.name)) or nil
  _cached_env.game = game
  _cached_env.ui_state = state
  _cached_env.last_turn = game and game.last_turn or nil
  _cached_env.finished = game and game.finished or nil
  _cached_env.winner_name = winner_name
  return _cached_env
end

return shared

--[[ mutate4lua-manifest
version=2
projectHash=9d897fbacc65ff0c
scope.0.id=chunk:src/state/ui_sync_shared.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=29
scope.0.semanticHash=b010761443642f13
scope.1.id=function:shared.is_only_turn_countdown:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=15
scope.1.semanticHash=16fb5b63621355c3
scope.2.id=function:shared.build_ui_env:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=26
scope.2.semanticHash=f99cce66ee1561aa
]]
