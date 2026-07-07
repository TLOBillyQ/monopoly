local board_query = require("src.rules.board.query")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("board_query_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("_test_queue_walk_visits_single_node", function()
    local visited = {}
    board_query.queue_walk({ "a" }, function(node, _enqueue)
      visited[#visited + 1] = node
    end)
    _assert_eq(#visited, 1, "single node: visited once")
    _assert_eq(visited[1], "a", "single node: correct value")
  end)

  it("_test_queue_walk_visits_empty_queue", function()
    local visited = {}
    board_query.queue_walk({}, function(node, _enqueue)
      visited[#visited + 1] = node
    end)
    _assert_eq(#visited, 0, "empty queue: nothing visited")
  end)

  it("_test_queue_walk_visits_nil_queue", function()
    local visited = {}
    board_query.queue_walk(nil, function(node, _enqueue)
      visited[#visited + 1] = node
    end)
    _assert_eq(#visited, 0, "nil queue: nothing visited")
  end)

  it("_test_queue_walk_enqueue_expands_breadth_first", function()
    local visited = {}
    board_query.queue_walk({ 1 }, function(node, enqueue)
      visited[#visited + 1] = node
      if node < 3 then
        enqueue(node + 1)
      end
    end)
    _assert_eq(#visited, 3, "bfs: visits 3 nodes")
    _assert_eq(visited[1], 1, "bfs: first node is 1")
    _assert_eq(visited[2], 2, "bfs: second node is 2")
    _assert_eq(visited[3], 3, "bfs: third node is 3")
  end)

  it("_test_queue_walk_multiple_enqueue_per_node", function()
    local visited = {}
    board_query.queue_walk({ 0 }, function(node, enqueue)
      visited[#visited + 1] = node
      if node == 0 then
        enqueue(1)
        enqueue(2)
      end
    end)
    _assert_eq(#visited, 3, "multi-enqueue: all enqueued nodes visited")
    _assert_eq(visited[1], 0, "multi-enqueue: root visited first")
    _assert_eq(visited[2], 1, "multi-enqueue: first enqueued second")
    _assert_eq(visited[3], 2, "multi-enqueue: second enqueued third")
  end)

  it("_test_queue_walk_visits_multiple_initial_nodes", function()
    local visited = {}
    board_query.queue_walk({ "x", "y", "z" }, function(node, _enqueue)
      visited[#visited + 1] = node
    end)
    _assert_eq(#visited, 3, "multi-initial: all 3 initial nodes visited")
    _assert_eq(visited[1], "x", "multi-initial: x first")
    _assert_eq(visited[2], "y", "multi-initial: y second")
    _assert_eq(visited[3], "z", "multi-initial: z third")
  end)
end)

-- Linear boards used to pin range boundaries. Tiles sit on row 0 with distinct
-- columns, so manhattan distance between indices i and j is |col_i - col_j|.
-- index_of_tile_id defaults to identity but can be overridden to model boards
-- whose id->index lookup differs from path order.
local function _linear_board(cols, index_of_override)
  local path = {}
  for i, col in ipairs(cols) do
    path[i] = { id = i, row = 0, col = col, type = "land" }
  end
  return {
    path = path,
    get_tile = function(_, idx) return path[idx] end,
    index_of_tile_id = index_of_override or function(_, id) return id end,
  }
end

local function _sorted_copy(list)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  table.sort(out)
  return out
end

describe("board_query.indices_in_range boundaries", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("_test_excludes_a_tile_co_located_with_the_start", function()
    -- Index 2 shares the start's position (distance 0). The strict distance > 0
    -- guard must drop it even though it is within range.
    local board = _linear_board({ 0, 0, 1 })
    local result = board_query.indices_in_range(board, 1, 5)
    _assert_eq(#result, 1, "co-located tile excluded: only the distance-1 tile remains")
    _assert_eq(result[1], 3, "co-located tile excluded: index 3 is the sole in-range tile")
  end)

  it("_test_excludes_the_index_reported_by_index_of_tile_id", function()
    -- The board's id->index lookup maps the start's id to index 2 (a far tile),
    -- so the self-exclusion guard must skip index 2, leaving no in-range tiles.
    local board = _linear_board({ 0, 5 }, function(_, id)
      if id == 1 then return 2 end
      return id
    end)
    local result = board_query.indices_in_range(board, 1, 10)
    _assert_eq(#result, 0, "index_of_tile_id exclusion: the reported index is dropped")
  end)

  it("_test_flatten_ignores_a_distance_zero_bucket", function()
    -- _flatten walks step 1..max, so a bucket keyed at 0 must never surface.
    local result = board_query._flatten_by_distance({ [0] = { 99 }, [1] = { 7 } }, 1)
    _assert_eq(#result, 1, "distance-0 bucket ignored: single flattened entry")
    _assert_eq(result[1], 7, "distance-0 bucket ignored: only the distance-1 index remains")
  end)

  it("_test_nil_distance_yields_no_candidates", function()
    -- distance defaults to 0, and max_dist <= 0 short-circuits to an empty list.
    local board = _linear_board({ 0, 1 })
    local result = board_query.indices_in_range(board, 1, nil)
    _assert_eq(#result, 0, "nil distance: no candidates in range")
  end)

  it("_test_distance_one_includes_the_adjacent_tile", function()
    -- max_dist == 1 must still pass the <= 0 gate and collect the distance-1 tile.
    local board = _linear_board({ 0, 1, 2 })
    local result = _sorted_copy(board_query.indices_in_range(board, 1, 1))
    _assert_eq(#result, 1, "distance 1: exactly the adjacent tile")
    _assert_eq(result[1], 2, "distance 1: index 2 is the adjacent tile")
  end)
end)
