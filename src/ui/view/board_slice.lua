local tiles_cfg = require("src.config.content.tiles")
local contiguous_count = require("src.ui.view.contiguous_count")

local board_slice = {}
local cached_board_tiles = {}

local _tiles_by_id = {}

for _, cfg in ipairs(tiles_cfg) do
  _tiles_by_id[cfg.id] = cfg
end

local function _project_tile_states(game)
  local board = game and game.board or nil
  if not board then
    return {}
  end
  local lookup = board.tile_lookup or {}
  local count_by_owner = {}
  local out = {}
  for tile_id, raw in pairs(lookup) do
    local entry = {
      owner_id = raw.owner_id,
      level = raw.level,
    }
    if raw.owner_id then
      local owner_counts = count_by_owner[raw.owner_id]
      if owner_counts == nil then
        owner_counts = contiguous_count.build_for_owner(board, raw.owner_id)
        count_by_owner[raw.owner_id] = owner_counts
      end
      local count = owner_counts[tile_id]
      if count and count > 0 then
        entry.contiguous_count = count
      end
    end
    out[tile_id] = entry
  end
  return out
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
    tile_states = _project_tile_states(game),
    overlays = _build_overlays(env),
    players = game.players,
    phase = turn.phase,
    move_anim = turn.move_anim,
    action_anim = turn.action_anim,
    move_followup_pending = turn.move_followup_pending == true,
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
  board.tile_states = _project_tile_states(game)
  board.overlays = _build_overlays(env)
  board.players = game.players
  board.phase = turn.phase
  board.move_anim = turn.move_anim
  board.action_anim = turn.action_anim
  board.move_followup_pending = turn.move_followup_pending == true
  board.turn_start_prompt_seq = turn.turn_start_prompt_seq or 0
  board.turn_start_prompt_player_id = turn.turn_start_prompt_player_id
  board.vehicle_resync_seq = turn.vehicle_resync_seq or 0
  board.tile_count = #board_tiles
  return board
end

return board_slice
