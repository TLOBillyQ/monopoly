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
    local cfg = tiles_by_id[tile_id]
    out[i] = {
      id = tile_id,
      name = (cfg and cfg.name) or tostring(tile_id),
      type = (cfg and cfg.type) or "default",
      price = cfg and cfg.price,
      row = cfg and cfg.row,
      col = cfg and cfg.col,
    }
  end
  return out
end

local BOARD_TILES = build_board_tiles()




function Presenter.present(store_state, runtime)
  runtime = runtime or {}
  local overlays
  if runtime.game and runtime.game.board and runtime.game.board.get_overlays then
    overlays = runtime.game.board:get_overlays()
  else
    overlays = { roadblocks = {}, mines = {} }
  end

  return {
    board = {
      tiles = BOARD_TILES,
      overlays = overlays,
    },
    state = store_state or {},
    last_turn = runtime.last_turn,
    finished = runtime.finished and true or false,
    winner_name = runtime.winner_name,
  }
end

return Presenter