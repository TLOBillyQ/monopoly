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

-- Present a UI-facing view model.
-- Input: store/state snapshot (a plain table), plus optional runtime info.
-- Output: { board = { tiles[] }, state = <snapshot>, last_turn, finished, winner_name }
function Presenter.present(store_state, runtime)
  runtime = runtime or {}
  return {
    board = {
      tiles = BOARD_TILES,
    },
    state = store_state or {},
    last_turn = runtime.last_turn,
    finished = runtime.finished and true or false,
    winner_name = runtime.winner_name,
  }
end

return Presenter
