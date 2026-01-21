local Presenter = {}

function Presenter.present(store_state, env)
  local state = store_state
  local turn = state.turn
  local board = state.board
  local tiles = board.tiles

  local game = env.game
  local current_idx = turn.current_player_index
  local current_name = game.players[current_idx].name
  local current_cash = game.players[current_idx].cash
  local turn_count = turn.turn_count

  local board_tile_count = 0
  if type(tiles) == "table" then
    for _ in pairs(tiles) do
      board_tile_count = board_tile_count + 1
    end
  end

  return {
    state = state,
    board = board,
    current_player_name = current_name,
    current_player_cash = current_cash,
    turn_count = turn_count,
    board_tile_count = board_tile_count,
    last_turn = env.last_turn,
    finished = env.finished,
    winner_name = env.winner_name,
  }
end

return Presenter
