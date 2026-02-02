local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

local Presenter = {}

local function build_board_tiles()
  local out = {}
  assert(map_cfg.path ~= nil, "missing map path")
  for i, tile_id in ipairs(map_cfg.path) do
    local cfg = tiles_by_id[tile_id]
    assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
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
  assert(env ~= nil and env.game ~= nil and env.game.board ~= nil and env.game.board.get_overlays ~= nil, "missing board overlays")
  return env.game.board:get_overlays()
end

local function resolve_current_player(state)
  local turn = state.turn
  local players = state.players
  assert(turn ~= nil and players ~= nil, "missing turn or players")
  local idx = turn.current_player_index
  return players[idx], turn
end

function Presenter.present(store_state, env)
  local current, turn = resolve_current_player(store_state)
  local overlays = build_overlays(env)

  return {
    board = {
      tiles = BOARD_TILES,
      overlays = overlays,
    },
    state = store_state,
    current_player_name = current.name,
    current_player_cash = current.cash,
    turn_count = turn.turn_count,
    board_tile_count = #BOARD_TILES,
    last_turn = env.last_turn,
    finished = env.finished,
    winner_name = env.winner_name,
  }
end

return Presenter
