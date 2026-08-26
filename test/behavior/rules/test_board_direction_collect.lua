local lu = require("luaunit")
local direction = require("src.rules.board.direction")
local _config_reset = require("test.support.config_reset")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 TestBoardDirectionCollect 类,
-- before_each → setUp,断言切到 lu.assertXxx,用例数与改写前一一对应(9 例)。

local function _assert_eq(a, b, msg)
  lu.assertEquals(a, b, msg)
end

local function _assert_set_contains(set, key, msg)
  lu.assertNotIsNil(set[key], tostring(msg) .. ": expected key " .. tostring(key) .. " in set")
end

local function _assert_set_not_contains(set, key, msg)
  lu.assertIsNil(set[key], tostring(msg) .. ": expected key " .. tostring(key) .. " absent from set")
end

local function _linear_ring_board(player_tile_id, move_dir)
  local ids = { 1, 2, 3, 4 }
  local tiles = {}
  local id_to_index = {}
  for i, id in ipairs(ids) do
    tiles[i] = { id = id, row = 1, col = i }
    id_to_index[id] = i
  end
  local outer_next = {}
  local outer_prev = {}
  for i, id in ipairs(ids) do
    local next_id = ids[(i % #ids) + 1]
    local prev_id = ids[((i - 2 + #ids) % #ids) + 1]
    outer_next[id] = next_id
    outer_prev[id] = prev_id
  end
  local map = {
    outer_next = outer_next,
    outer_prev = outer_prev,
    neighbors = { [1] = {}, [2] = {}, [3] = {}, [4] = {} },
    entry_points = {},
    start_id = 1,
    direction = function(from_id, to_id)
      return "right"
    end,
  }
  local board = {
    map = map,
    get_tile = function(self, index)
      return tiles[index]
    end,
    index_of_tile_id = function(self, id)
      return id_to_index[id]
    end,
  }
  local player = {
    position = player_tile_id,
    status = { move_dir = move_dir },
  }
  return board, player
end

TestBoardDirectionCollect = {}

function TestBoardDirectionCollect:setUp()
  _config_reset.reset_all()
end

function TestBoardDirectionCollect:test_collect_forward_indices_walks_ring_forward()
  local board, player = _linear_ring_board(1, nil)
  local result = direction.collect_forward_indices(board, player, 3)
  _assert_eq(#result.list, 3, "forward walk 3 steps: list length")
  _assert_eq(result.list[1].index, 2, "forward walk: step 1 lands on tile 2")
  _assert_eq(result.list[2].index, 3, "forward walk: step 2 lands on tile 3")
  _assert_eq(result.list[3].index, 4, "forward walk: step 3 lands on tile 4")
  _assert_set_contains(result.set, 2, "forward set contains tile index 2")
  _assert_set_contains(result.set, 3, "forward set contains tile index 3")
  _assert_set_contains(result.set, 4, "forward set contains tile index 4")
end

function TestBoardDirectionCollect:test_collect_forward_indices_zero_steps_returns_empty()
  local board, player = _linear_ring_board(1, nil)
  local result = direction.collect_forward_indices(board, player, 0)
  _assert_eq(#result.list, 0, "zero steps: empty list")
  _assert_set_not_contains(result.set, 2, "zero steps: set is empty")
end

function TestBoardDirectionCollect:test_collect_forward_indices_step_field_matches_distance()
  local board, player = _linear_ring_board(2, nil)
  local result = direction.collect_forward_indices(board, player, 2)
  _assert_eq(result.list[1].step, 1, "step field: first entry is step 1")
  _assert_eq(result.list[2].step, 2, "step field: second entry is step 2")
end

function TestBoardDirectionCollect:test_collect_backward_indices_walks_ring_backward()
  local board, player = _linear_ring_board(3, nil)
  local result = direction.collect_backward_indices(board, player, 2)
  _assert_eq(#result.list, 2, "backward walk 2 steps: list length")
  _assert_eq(result.list[1].index, 2, "backward walk: step 1 lands on tile 2")
  _assert_eq(result.list[2].index, 1, "backward walk: step 2 lands on tile 1")
  _assert_set_contains(result.set, 2, "backward set contains tile index 2")
  _assert_set_contains(result.set, 1, "backward set contains tile index 1")
end

function TestBoardDirectionCollect:test_collect_backward_indices_zero_steps_returns_empty()
  local board, player = _linear_ring_board(1, nil)
  local result = direction.collect_backward_indices(board, player, 0)
  _assert_eq(#result.list, 0, "zero backward steps: empty list")
end

function TestBoardDirectionCollect:test_collect_backward_indices_step_field_matches_distance()
  local board, player = _linear_ring_board(4, nil)
  local result = direction.collect_backward_indices(board, player, 2)
  _assert_eq(result.list[1].step, 1, "backward step field: first entry is step 1")
  _assert_eq(result.list[2].step, 2, "backward step field: second entry is step 2")
end

function TestBoardDirectionCollect:test_try_resolve_forward_next_id_returns_outer_next()
  local map = {
    outer_next = { [1] = 2 },
    outer_prev = {},
    neighbors = {},
    entry_points = {},
  }
  local next_id = direction.try_resolve_forward_next_id(map, 1, {}, nil, nil, true, nil)
  _assert_eq(next_id, 2, "try_resolve_forward_next_id: returns outer_next")
end

function TestBoardDirectionCollect:test_try_resolve_forward_next_id_returns_nil_when_no_next()
  local map = {
    outer_next = {},
    outer_prev = {},
    neighbors = { [1] = {} },
    entry_points = {},
  }
  local next_id = direction.try_resolve_forward_next_id(map, 1, {}, nil, nil, true, nil)
  _assert_eq(next_id, nil, "try_resolve_forward_next_id: returns nil when no path")
end

function TestBoardDirectionCollect:test_collect_forward_and_backward_do_not_include_player_position()
  local board, player = _linear_ring_board(1, nil)
  local fwd = direction.collect_forward_indices(board, player, 2)
  local bwd = direction.collect_backward_indices(board, player, 2)
  _assert_set_not_contains(fwd.set, 1, "forward set excludes player position")
  _assert_set_not_contains(bwd.set, 1, "backward set excludes player position")
end


return TestBoardDirectionCollect
