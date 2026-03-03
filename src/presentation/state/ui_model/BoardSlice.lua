local tiles_cfg = require("Config.Generated.Tiles")

local board_slice = {}
local cached_board_tiles = {}

local _tiles_by_id = {}

for _, cfg in ipairs(tiles_cfg) do
  _tiles_by_id[cfg.id] = cfg
end

local function _build_board_tiles(board_path)
  local out = {}
  assert(type(board_path) == "table", "missing board path")
  for i, tile in ipairs(board_path) do
    local tile_id = tile and tile.id
    local cfg = _tiles_by_id[tile_id]
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

local function _build_overlays(env)
  assert(env ~= nil and env.game ~= nil and env.game.board ~= nil and env.game.board.get_overlays ~= nil,
    "missing board overlays")
  return env.game.board:get_overlays()
end

function board_slice.board_tiles()
  return cached_board_tiles
end

function board_slice.tile_count()
  return #cached_board_tiles
end

function board_slice.build(game, env, turn)
  local board_path = assert(game and game.board and game.board.path, "missing game.board.path")
  local board_tiles = _build_board_tiles(board_path)
  cached_board_tiles = board_tiles
  return {
    tiles = board_tiles,
    tile_states = game.board and game.board.tile_lookup or {},
    overlays = _build_overlays(env),
    players = game.players,
    phase = turn.phase,
    move_anim = turn.move_anim,
    turn_start_prompt_seq = turn.turn_start_prompt_seq or 0,
    turn_start_prompt_player_id = turn.turn_start_prompt_player_id,
    vehicle_resync_seq = turn.vehicle_resync_seq or 0,
    tile_count = #board_tiles,
  }
end

function board_slice.update(board, game, env, turn)
  local board_path = assert(game and game.board and game.board.path, "missing game.board.path")
  local board_tiles = _build_board_tiles(board_path)
  cached_board_tiles = board_tiles
  board = board or {}
  board.tiles = board_tiles
  board.tile_states = game.board and game.board.tile_lookup or {}
  board.overlays = _build_overlays(env)
  board.players = game.players
  board.phase = turn.phase
  board.move_anim = turn.move_anim
  board.turn_start_prompt_seq = turn.turn_start_prompt_seq or 0
  board.turn_start_prompt_player_id = turn.turn_start_prompt_player_id
  board.vehicle_resync_seq = turn.vehicle_resync_seq or 0
  board.tile_count = #board_tiles
  return board
end

return board_slice
