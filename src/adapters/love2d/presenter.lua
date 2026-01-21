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
  for i, tile_id in ipairs(map_cfg.path) do
    local cfg = tiles_by_id[tile_id]
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




function Presenter.present(store_state, runtime)
  local overlays = runtime.game.board:get_overlays()

  return {
    board = {
      tiles = BOARD_TILES,
      overlays = overlays,
    },
    state = store_state,
    last_turn = runtime.last_turn,
    finished = runtime.finished,
    winner_name = runtime.winner_name,
  }
end

return Presenter
