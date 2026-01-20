local Presenter = {}

function Presenter.present(store_state, env)
  local state = store_state or {}
  local turn = state.turn or {}
  local players = state.players or {}
  local board = state.board or {}
  local tiles = board.tiles or {}

  local game = env and env.game
  local current_idx = turn.current_player_index or 1
  local current = players[current_idx]
  local current_name = current and current.name or (game and game.players[current_idx] and game.players[current_idx].name) or "-"
  local current_cash = current and current.cash or (game and game.players[current_idx] and game.players[current_idx].cash) or 0
  local turn_count = turn.turn_count or 0

  local board_tile_count = 0
  if type(tiles) == "table" then
    for _ in pairs(tiles) do
      board_tile_count = board_tile_count + 1
    end
  end

  return {
    current_player_name = current_name,
    current_player_cash = current_cash,
    turn_count = turn_count,
    board_tile_count = board_tile_count,
    last_turn = env and env.last_turn or nil,
    finished = env and env.finished or false,
    winner_name = env and env.winner_name or nil,
  }
end

return Presenter
