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
