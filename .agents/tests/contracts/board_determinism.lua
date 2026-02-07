local board_class = require("src.game.board.Board")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local function _build_board()
  local path = {
    { id = 1, type = "land" },
    { id = 2, type = "land" },
    { id = 3, type = "land" },
  }
  local tile_lookup = {
    [1] = path[1],
    [2] = path[2],
    [3] = path[3],
  }
  local map = {
    neighbors = {
      [1] = { left = 3, up = 2 },
      [2] = { down = 1 },
      [3] = { right = 1 },
    },
    outer_next = {},
    outer_prev = {},
    entry_points = {},
    turn_right = {},
    turn_left = {},
    start_id = 1,
  }
  map.direction = function(from_id, to_id)
    local neigh = map.neighbors[from_id] or {}
    for dir, nid in pairs(neigh) do
      if nid == to_id then
        return dir
      end
    end
    return nil
  end
  return board_class:new({
    path = path,
    tile_lookup = tile_lookup,
    branches = {},
    map = map,
    overlays = { roadblocks = {}, mines = {} },
  })
end

local board = _build_board()
local next_index_1, _, dir_1 = board:step_forward_by_facing(1, nil, nil)
local next_index_2, _, dir_2 = board:step_forward_by_facing(1, nil, nil)
_assert_eq(next_index_1, next_index_2, "deterministic next index")
_assert_eq(dir_1, dir_2, "deterministic next dir")

local back_index_1 = board:step_backward_by_facing(1, nil)
local back_index_2 = board:step_backward_by_facing(1, nil)
_assert_eq(back_index_1, back_index_2, "deterministic back index")

print("Contract board_determinism passed")
