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
