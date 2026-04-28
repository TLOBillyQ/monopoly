local board_query = require("src.rules.board.query")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _test_queue_walk_visits_single_node()
  local visited = {}
  board_query.queue_walk({ "a" }, function(node, _enqueue)
    visited[#visited + 1] = node
  end)
  _assert_eq(#visited, 1, "single node: visited once")
  _assert_eq(visited[1], "a", "single node: correct value")
end

local function _test_queue_walk_visits_empty_queue()
  local visited = {}
  board_query.queue_walk({}, function(node, _enqueue)
    visited[#visited + 1] = node
  end)
  _assert_eq(#visited, 0, "empty queue: nothing visited")
end

local function _test_queue_walk_visits_nil_queue()
  local visited = {}
  board_query.queue_walk(nil, function(node, _enqueue)
    visited[#visited + 1] = node
  end)
  _assert_eq(#visited, 0, "nil queue: nothing visited")
end

local function _test_queue_walk_enqueue_expands_breadth_first()
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
end

local function _test_queue_walk_multiple_enqueue_per_node()
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
end

local function _test_queue_walk_visits_multiple_initial_nodes()
  local visited = {}
  board_query.queue_walk({ "x", "y", "z" }, function(node, _enqueue)
    visited[#visited + 1] = node
  end)
  _assert_eq(#visited, 3, "multi-initial: all 3 initial nodes visited")
  _assert_eq(visited[1], "x", "multi-initial: x first")
  _assert_eq(visited[2], "y", "multi-initial: y second")
  _assert_eq(visited[3], "z", "multi-initial: z third")
end

return {
  name = "board_query_crap_coverage",
  tests = {
    { name = "_test_queue_walk_visits_single_node", run = _test_queue_walk_visits_single_node },
    { name = "_test_queue_walk_visits_empty_queue", run = _test_queue_walk_visits_empty_queue },
    { name = "_test_queue_walk_visits_nil_queue", run = _test_queue_walk_visits_nil_queue },
    { name = "_test_queue_walk_enqueue_expands_breadth_first", run = _test_queue_walk_enqueue_expands_breadth_first },
    { name = "_test_queue_walk_multiple_enqueue_per_node", run = _test_queue_walk_multiple_enqueue_per_node },
    { name = "_test_queue_walk_visits_multiple_initial_nodes", run = _test_queue_walk_visits_multiple_initial_nodes },
  },
}
