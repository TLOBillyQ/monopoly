local map_cfg = require("src.config.map")
local tiles_cfg = require("src.config.tiles")

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  if cfg.id then
    tiles_by_id[cfg.id] = cfg
  end
end

local Presenter = {}

local function build_board_tiles()
  local out = {}
  for i, tile_id in ipairs(map_cfg.path or {}) do
    local cfg = tiles_by_id[tile_id] or {}
    out[i] = {
      id = tile_id,
      name = cfg.name,
      type = cfg.type,
      price = cfg.price,
      row = cfg.row,
      col = cfg.col,
    }
  end
  return out
end

local BOARD_TILES = build_board_tiles()

local function build_overlays(env)
  if env and env.game and env.game.board and env.game.board.get_overlays then
    return env.game.board:get_overlays()
  end
  return { roadblocks = {}, mines = {} }
end

local function resolve_current_player(state)
  if not state then
    return nil, nil
  end
  local turn = state.turn
  local players = state.players
  if not (turn and players) then
    return nil, turn
  end
  local idx = turn.current_player_index
  return players[idx], turn
end

function Presenter.present(store_state, env)
  local current, turn = resolve_current_player(store_state)
  local overlays = build_overlays(env)
  if not overlays then
    overlays = { roadblocks = {}, mines = {} }
  end

  return {
    board = {
      tiles = BOARD_TILES,
      overlays = overlays,
    },
    state = store_state,
    current_player_name = current and current.name or nil,
    current_player_cash = current and current.cash or nil,
    turn_count = turn and turn.turn_count or nil,
    board_tile_count = #BOARD_TILES,
    last_turn = env and env.last_turn or nil,
    finished = env and env.finished or nil,
    winner_name = env and env.winner_name or nil,
  }
end

return Presenter
