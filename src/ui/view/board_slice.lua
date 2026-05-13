local tiles_cfg = require("src.config.content.tiles")
local contiguous_count = require("src.ui.view.contiguous_count")

local board_slice = {}
local cached_board_tiles = {}

local _tiles_by_id = {}

for _, cfg in ipairs(tiles_cfg) do
  _tiles_by_id[cfg.id] = cfg
end

local _tile_state_out = {}
local _tile_state_entries = {}
local _count_by_owner = {}

local function _project_tile_states(game)
  local board = game and game.board or nil
  if not board then
    return _tile_state_out
  end
  local lookup = board.tile_lookup or {}
  for k in pairs(_tile_state_out) do
    _tile_state_out[k] = nil
  end
  for k in pairs(_count_by_owner) do
    _count_by_owner[k] = nil
  end
  for tile_id, raw in pairs(lookup) do
    local entry = _tile_state_entries[tile_id]
    if entry == nil then
      entry = {}
      _tile_state_entries[tile_id] = entry
    end
    entry.owner_id = raw.owner_id
    entry.level = raw.level
    entry.contiguous_count = nil
    if raw.owner_id then
      local owner_counts = _count_by_owner[raw.owner_id]
      if owner_counts == nil then
        owner_counts = contiguous_count.build_for_owner(board, raw.owner_id)
        _count_by_owner[raw.owner_id] = owner_counts
      end
      local count = owner_counts[tile_id]
      if count and count > 0 then
        entry.contiguous_count = count
      end
    end
    _tile_state_out[tile_id] = entry
  end
  return _tile_state_out
end

local _cached_board_path_ref = nil

local function _build_board_tiles(board_path)
  if _cached_board_path_ref == board_path and #cached_board_tiles > 0 then
    return cached_board_tiles
  end
  _cached_board_path_ref = board_path
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

function board_slice.tile_count()
  return #cached_board_tiles
end

local function _populate_board(target, board_tiles, game, env, turn)
  target.tiles = board_tiles
  target.tile_states = _project_tile_states(game)
  target.overlays = _build_overlays(env)
  target.players = game.players
  target.phase = turn.phase
  target.move_anim = turn.move_anim
  target.action_anim = turn.action_anim
  target.move_followup_pending = turn.move_followup_pending == true
  target.turn_start_prompt_seq = turn.turn_start_prompt_seq or 0
  target.turn_start_prompt_player_id = turn.turn_start_prompt_player_id
  target.tile_count = #board_tiles
  return target
end

function board_slice.update(board, game, env, turn)
  local board_path = assert(game and game.board and game.board.path, "missing game.board.path")
  local board_tiles = _build_board_tiles(board_path)
  cached_board_tiles = board_tiles
  return _populate_board(board or {}, board_tiles, game, env, turn)
end

function board_slice.build(game, env, turn)
  return board_slice.update(nil, game, env, turn)
end

return board_slice
