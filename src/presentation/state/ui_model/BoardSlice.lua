local map_cfg = require("Config.Map")
local tiles_cfg = require("Config.Generated.Tiles")

local board_slice = {}

local _tiles_by_id = {}

for _, cfg in ipairs(tiles_cfg) do
  _tiles_by_id[cfg.id] = cfg
end

local function _build_board_tiles()
  local out = {}
  assert(map_cfg.path ~= nil, "missing map path")
  for i, tile_id in ipairs(map_cfg.path) do
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

local _board_tiles = _build_board_tiles()

local function _build_overlays(env)
  assert(env ~= nil and env.game ~= nil and env.game.board ~= nil and env.game.board.get_overlays ~= nil,
    "missing board overlays")
  return env.game.board:get_overlays()
end

function board_slice.board_tiles()
  return _board_tiles
end

function board_slice.tile_count()
  return #_board_tiles
end

function board_slice.build(game, env, turn)
  return {
    tiles = _board_tiles,
    tile_states = game.board and game.board.tile_lookup or {},
    overlays = _build_overlays(env),
    players = game.players,
    phase = turn.phase,
    move_anim = turn.move_anim,
    turn_start_prompt_seq = turn.turn_start_prompt_seq or 0,
    turn_start_prompt_player_id = turn.turn_start_prompt_player_id,
    vehicle_resync_seq = turn.vehicle_resync_seq or 0,
    tile_count = #_board_tiles,
  }
end

function board_slice.update(board, game, env, turn)
  board = board or {}
  board.tiles = _board_tiles
  board.tile_states = game.board and game.board.tile_lookup or {}
  board.overlays = _build_overlays(env)
  board.players = game.players
  board.phase = turn.phase
  board.move_anim = turn.move_anim
  board.turn_start_prompt_seq = turn.turn_start_prompt_seq or 0
  board.turn_start_prompt_player_id = turn.turn_start_prompt_player_id
  board.vehicle_resync_seq = turn.vehicle_resync_seq or 0
  board.tile_count = #_board_tiles
  return board
end

return board_slice
