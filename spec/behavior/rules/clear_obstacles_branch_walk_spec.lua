-- Contract tests for _handle_clear_obstacles_ahead.
-- Payload must use branch-based walk data:
-- { kind="clear_obstacles", branches=..., duration=... }.
-- luacheck: ignore 211

local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local action_anim_port = require("src.foundation.ports.action_anim")
local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local obstacle_clear = require("src.rules.items.obstacle_clear")
local obstacle_clear_tiles = require("src.rules.items.obstacle_clear_tiles")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local event_kinds = require("src.config.gameplay.event_kinds")
local Board = require("src.rules.board")

local _assert_eq = support.assert_eq

local function _new_game()
  return support.new_game({ map = default_map })
end

-- Enable action_anim so action_anim_port.queue actually captures a payload.
-- Returns the captured payload after calling fn().
local function _capture_anim_payload(game, fn)
  local captured = nil
  game.anim_gate_port = { wait_action_anim = true }
  game.queue_action_anim = function(_, payload)
    captured = payload
  end
  support.with_patches({
    {
      target = action_anim_port,
      key = "queue",
      value = function(_, payload)
        captured = payload
        return true
      end,
    },
  }, fn)
  return captured
end

describe("domain.clear_obstacles_branch_walk", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("linear_path_produces_single_branch_with_12_entries", function()
    local g = _new_game()
    local p = g:current_player()

    -- Position player at index 1 (start tile) and face "right" along outer ring.
    -- The outer ring starts at (9,9) and goes left, so first direction is "left".
    -- We set move_dir to match the natural forward direction at index 1.
    -- In default_map, outer ring goes left from (9,9), so forward = "left".
    g:update_player_position(p, 1)
    g:set_player_status(p, "move_dir", "left")

    -- Place roadblocks at indices 3, 7, 10 (ahead of player on outer ring).
    g.board:place_roadblock(3)
    g.board:place_roadblock(7)
    g.board:place_roadblock(10)

    local cfg = { distance = 12 }
    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    _assert_eq(#payload.branches, 1, "linear path should produce exactly 1 branch")

    local branch = payload.branches[1]
    assert(type(branch) == "table", "branch should be a table")
    _assert_eq(#branch, 12, "linear branch should have exactly 12 entries (full distance)")

    -- Find positions 3, 7, 10 relative to starting position 1.
    -- Entries are ordered: branch[1]=index 2, branch[2]=index 3, ..., branch[n]=index n+1
    -- (player is at index 1, walk starts from neighbor of index 1)
    local obstacle_relative_positions = { 2, 6, 9 } -- branch[2]=idx3, branch[6]=idx7, branch[9]=idx10
    for _, rel_pos in ipairs(obstacle_relative_positions) do
      assert(type(branch[rel_pos]) == "table",
        "branch entry at position " .. rel_pos .. " should be a table")
      assert(branch[rel_pos].has_obstacle == true,
        "branch entry at relative position " .. rel_pos .. " should have has_obstacle=true")
    end

    -- Spot-check: first entry should not be an obstacle
    assert(branch[1].has_obstacle == false,
      "branch[1] (index 2, no obstacle) should have has_obstacle=false")

    -- Each entry must have tile_index field
    for i, entry in ipairs(branch) do
      assert(type(entry) == "table" and entry.tile_index ~= nil,
        "branch entry " .. i .. " must have tile_index field")
    end
  end)

  it("forked_path_produces_two_branches", function()
    local g = _new_game()
    local p = g:current_player()

    -- Find the index of the tile just before the fork.
    -- In default_map, outer ring position (9,6) leads forward to (9,5),
    -- which has two forward neighbors: (9,4) and (8,5).
    -- outer_ccw_coords: {9,9},{9,8},{9,7},{9,6},{9,5},...
    -- So outer ring index 4 = (9,6), index 5 = (9,5).
    -- Place player at index 4 facing "left" (toward (9,5)).
    -- After 1 step we reach (9,5) which is the fork.
    local fork_approach_index = 4  -- tile at (9,6)
    g:update_player_position(p, fork_approach_index)
    g:set_player_status(p, "move_dir", "left")

    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    assert(#payload.branches >= 2,
      "forked path should produce at least 2 branches, got " .. tostring(#payload.branches))

    -- Each branch must be an ordered array of entries
    for b_idx, branch in ipairs(payload.branches) do
      assert(type(branch) == "table", "branch " .. b_idx .. " should be a table")
      assert(#branch > 0, "branch " .. b_idx .. " should be non-empty")
      for e_idx, entry in ipairs(branch) do
        assert(type(entry) == "table", "branch " .. b_idx .. " entry " .. e_idx .. " should be a table")
        assert(entry.tile_index ~= nil,
          "branch " .. b_idx .. " entry " .. e_idx .. " must have tile_index")
        assert(type(entry.has_obstacle) == "boolean",
          "branch " .. b_idx .. " entry " .. e_idx .. " must have boolean has_obstacle")
      end
    end
  end)

  it("dead_end_stops_at_board_edge", function()
    local g = _new_game()
    local p = g:current_player()

    -- Build a synthetic 6-tile linear board: tiles with ids 101..106.
    -- Neighbor chain: 101→102→103→104→105→106 (rightward).
    -- No outgoing neighbor from tile 106 (dead end).
    -- Player at index 1 (tile 101), distance=12, expect 5 entries in branch.
    local tiles = {}
    local tile_lookup = {}
    local neighbors_map = {}
    local ids = {101, 102, 103, 104, 105, 106}
    for i, id in ipairs(ids) do
      local t = { id = id, name = "T" .. i, type = "land", row = i, col = 1 }
      tiles[i] = t
      tile_lookup[id] = t
      neighbors_map[id] = {}
    end
    -- Chain neighbors: 101←→102←→103←→104←→105←→106 using "right"/"left"
    for i = 1, #ids - 1 do
      neighbors_map[ids[i]]["right"] = ids[i + 1]
      neighbors_map[ids[i + 1]]["left"] = ids[i]
    end

    local synthetic_board = Board:new({
      tile_lookup = tile_lookup,
      path = tiles,
      branches = {},
      map = {
        neighbors = neighbors_map,
        outer_next = {},
        outer_prev = {},
        entry_points = {},
        start_id = ids[1],
        direction = function(from_id, to_id)
          -- simple: if to_id > from_id it's "right", else "left"
          local from_pos = 0
          local to_pos = 0
          for i, id in ipairs(ids) do
            if id == from_id then from_pos = i end
            if id == to_id then to_pos = i end
          end
          return to_pos > from_pos and "right" or "left"
        end,
      },
      overlays = {
        roadblocks = {},
        mines = {},
      },
    })

    -- Swap the game's board with our synthetic board.
    local original_board = g.board
    g.board = synthetic_board

    -- Player at index 1 (tile 101), facing "right".
    p.position = 1
    g:set_player_status(p, "move_dir", "right")

    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    -- Restore original board
    g.board = original_board

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    _assert_eq(#payload.branches, 1, "dead-end path should produce exactly 1 branch")

    local branch = payload.branches[1]
    assert(type(branch) == "table", "branch should be a table")
    _assert_eq(#branch, 5,
      "dead-end branch should stop at board edge with 5 entries, not padded to 12")
  end)

  it("duration_is_positive_number_in_payload", function()
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, 1)
    g:set_player_status(p, "move_dir", "left")

    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    assert(type(payload.duration) == "number",
      "payload.duration must be a number, got " .. type(payload.duration))
    assert(payload.duration > 0,
      "payload.duration must be positive, got " .. tostring(payload.duration))
    -- Sanity range: between 0.1s and 30s
    assert(payload.duration >= 0.1 and payload.duration <= 30,
      "payload.duration out of reasonable range [0.1, 30]: " .. tostring(payload.duration))
  end)
end)

-- Mutation-survivor coverage for obstacle_clear.handle / _queue_anim / _new_state
-- and the obstacle_clear_tiles / obstacle_clear_walk helpers. Each test pins a
-- boundary or count so a specific mutant flips an observable assertion.
describe("domain.clear_obstacles_mutation_survivors", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  -- Build a synthetic land board from an ordered id list plus a neighbor map.
  -- Path order fixes tile_index (ids[i] -> index i); overlays start empty.
  local function _build_board(ids, neighbors_map)
    local tiles = {}
    local tile_lookup = {}
    for i, id in ipairs(ids) do
      local t = { id = id, name = "T" .. id, type = "land", row = i, col = 1 }
      tiles[i] = t
      tile_lookup[id] = t
    end
    return Board:new({
      tile_lookup = tile_lookup,
      path = tiles,
      branches = {},
      map = {
        neighbors = neighbors_map,
        outer_next = {},
        outer_prev = {},
        entry_points = {},
        start_id = ids[1],
      },
      overlays = { roadblocks = {}, mines = {} },
    })
  end

  -- Linear left/right neighbor chain over the given ids.
  local function _chain(ids)
    local neigh = {}
    for _, id in ipairs(ids) do neigh[id] = {} end
    for i = 1, #ids - 1 do
      neigh[ids[i]].right = ids[i + 1]
      neigh[ids[i + 1]].left = ids[i]
    end
    return neigh
  end

  -- Seat the current player at path index 1 of the swapped board, facing move_dir.
  local function _seat_player(g, board, move_dir)
    g.board = board
    local p = g:current_player()
    p.position = 1
    g:set_player_status(p, "move_dir", move_dir)
    return p
  end

  -- Run obstacle_clear.handle with action_anim_port.queue patched to capture the
  -- payload and return queue_return; yields both the payload and handle result.
  local function _run_handle(g, p, cfg, queue_return)
    local captured, result = nil, nil
    support.with_patches({
      {
        target = action_anim_port,
        key = "queue",
        value = function(_, payload)
          captured = payload
          return queue_return
        end,
      },
    }, function()
      result = obstacle_clear.handle(g, p, cfg, {})
    end)
    return captured, result
  end

  local function _install_event_capture(g)
    local events = {}
    g.event_feed_port = {
      publish = function(_, _, event)
        events[#events + 1] = event
        return true
      end,
    }
    return events
  end

  local function _has_cleared_event(events)
    for _, event in ipairs(events) do
      if event.kind == event_kinds.obstacle_cleared then
        return true
      end
    end
    return false
  end

  it("payload_reports_exact_roadblock_and_mine_counts", function()
    local g = _new_game()
    local board = _build_board({ 60, 61, 62, 63, 64 }, _chain({ 60, 61, 62, 63, 64 }))
    board:place_roadblock(2)
    board:place_roadblock(4)
    board:place_mine(3)
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    assert(type(payload) == "table", "handle should queue a payload")
    _assert_eq(payload.roadblock_cleared, 2, "two roadblocks on the path must be counted exactly")
    _assert_eq(payload.mine_cleared, 1, "one mine on the path must be counted exactly")
  end)

  it("no_obstacles_reports_zero_counts_and_publishes_no_cleared_event", function()
    local g = _new_game()
    local events = _install_event_capture(g)
    local board = _build_board({ 80, 81, 82 }, _chain({ 80, 81, 82 }))
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(payload.roadblock_cleared, 0, "no roadblocks means zero roadblock_cleared")
    _assert_eq(payload.mine_cleared, 0, "no mines means zero mine_cleared")
    _assert_eq(_has_cleared_event(events), false,
      "no obstacles cleared must not publish an obstacle_cleared event")
  end)

  it("single_obstacle_publishes_cleared_event", function()
    local g = _new_game()
    local events = _install_event_capture(g)
    local board = _build_board({ 70, 71, 72 }, _chain({ 70, 71, 72 }))
    board:place_roadblock(2)
    local p = _seat_player(g, board, "right")

    _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(_has_cleared_event(events), true,
      "clearing exactly one obstacle must publish an obstacle_cleared event")
  end)

  it("empty_reachable_set_uses_default_duration", function()
    local g = _new_game()
    -- Start tile has an (empty) neighbor entry but no forward directions.
    local board = _build_board({ 90 }, { [90] = {} })
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(#payload.branches, 0, "no reachable tiles yields no branches")
    _assert_eq(payload.duration, 1.0,
      "empty branches must fall back to the default action-anim duration")
  end)

  it("short_branch_duration_stays_below_default", function()
    local g = _new_game()
    local board = _build_board({ 100, 101, 102, 103 }, _chain({ 100, 101, 102, 103 }))
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    local expected = 3 * (3.0 / runtime_constants.robot_speed)
    assert(payload.duration < 1.0,
      "a 3-tile branch must compute a duration below the 1.0s default, got " .. tostring(payload.duration))
    assert(math.abs(payload.duration - expected) < 1e-6,
      "duration should equal longest_branch * step_time, got " .. tostring(payload.duration))
  end)

  it("cfg_distance_limits_branch_length", function()
    local g = _new_game()
    local ids = { 110, 111, 112, 113, 114 }
    local board = _build_board(ids, _chain(ids))
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 2 }, true)

    _assert_eq(#payload.branches, 1, "linear board yields a single branch")
    _assert_eq(#payload.branches[1], 2, "cfg.distance=2 must cap the branch at two tiles")
  end)

  it("handle_marks_action_anim_when_queue_accepts", function()
    local g = _new_game()
    local ids = { 200, 201, 202 }
    local board = _build_board(ids, _chain(ids))
    local p = _seat_player(g, board, "right")

    local _, result = _run_handle(g, p, { distance = 12 }, true)

    assert(type(result) == "table", "queued handle should return a table result")
    _assert_eq(result.ok, true, "queued handle result must report ok=true")
    _assert_eq(result.action_anim, true, "queued handle result must report action_anim=true")
  end)

  it("handle_returns_true_when_queue_declines", function()
    local g = _new_game()
    local ids = { 210, 211, 212 }
    local board = _build_board(ids, _chain(ids))
    local p = _seat_player(g, board, "right")

    local _, result = _run_handle(g, p, { distance = 12 }, false)

    _assert_eq(result, true, "when queue returns falsy, handle must return the bare true value")
  end)

  it("first_tile_dead_end_still_records_one_branch", function()
    local g = _new_game()
    -- Start -> 11, but 11 has no neighbor entry at all (immediate dead end).
    local board = _build_board({ 10, 11 }, { [10] = { right = 11 } })
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(#payload.branches, 1, "an immediate dead end must still append exactly one branch")
    _assert_eq(#payload.branches[1], 1, "the branch holds the single reachable tile")
  end)

  it("first_tile_only_back_neighbor_records_one_branch", function()
    local g = _new_game()
    -- 21 has only the back-pointing neighbor, so it has no forward fork.
    local board = _build_board({ 20, 21 }, { [20] = { right = 21 }, [21] = { left = 20 } })
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(#payload.branches, 1, "a back-only first tile must append exactly one branch")
    _assert_eq(#payload.branches[1], 1, "the branch holds the single reachable tile")
  end)

  it("mid_walk_dangling_neighbor_records_branch", function()
    local g = _new_game()
    -- 32 points forward to id 999 which is not on the board (dangling edge).
    local board = _build_board({ 30, 31, 32 }, {
      [30] = { right = 31 },
      [31] = { left = 30, right = 32 },
      [32] = { left = 31, right = 999 },
    })
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(#payload.branches, 1, "a mid-walk dangling edge must append exactly one branch")
    _assert_eq(#payload.branches[1], 2, "the branch holds the two reachable tiles before the edge")
  end)

  it("first_tile_fork_produces_two_independent_branches", function()
    local g = _new_game()
    -- 40 -> 41, and 41 forks up->42 and down->43 (each a dead end).
    local board = _build_board({ 40, 41, 42, 43 }, {
      [40] = { right = 41 },
      [41] = { left = 40, up = 42, down = 43 },
      [42] = { down = 41 },
      [43] = { up = 41 },
    })
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(#payload.branches, 2, "a first-tile fork must yield two branches")
    local endpoints = {}
    for _, branch in ipairs(payload.branches) do
      _assert_eq(#branch, 2, "each fork branch must stay length 2 (no shared-path corruption)")
      endpoints[branch[#branch].tile_index] = true
    end
    assert(endpoints[3] and endpoints[4], "the two branches must end on distinct fork tiles")
  end)

  it("mid_walk_fork_produces_two_independent_branches", function()
    local g = _new_game()
    -- 50 -> 51 -> 52, and 52 forks up->53 and down->54 (each a dead end).
    local board = _build_board({ 50, 51, 52, 53, 54 }, {
      [50] = { right = 51 },
      [51] = { left = 50, right = 52 },
      [52] = { left = 51, up = 53, down = 54 },
      [53] = { down = 52 },
      [54] = { up = 52 },
    })
    local p = _seat_player(g, board, "right")

    local payload = _run_handle(g, p, { distance = 12 }, true)

    _assert_eq(#payload.branches, 2, "a mid-walk fork must yield two branches")
    local endpoints = {}
    for _, branch in ipairs(payload.branches) do
      _assert_eq(#branch, 3, "each fork branch must stay length 3 (no shared-path corruption)")
      endpoints[branch[#branch].tile_index] = true
    end
    assert(endpoints[4] and endpoints[5], "the two branches must end on distinct fork tiles")
  end)

  it("resolve_initial_dirs_turns_around_via_opposite_when_facing_blocked", function()
    -- facing "left" is absent from start_neigh, so resolution must consult
    -- direction_constants.opposite["left"] = "right" and return the forward dirs.
    local result = obstacle_clear_tiles.resolve_initial_dirs({ up = 5, down = 6 }, "left")

    assert(type(result) == "table", "blocked facing must still return a forward-dir table")
    _assert_eq(#result, 2, "both non-back neighbors must be exposed")
    _assert_eq(result[1], "down", "forward dirs must be sorted ascending")
    _assert_eq(result[2], "up", "forward dirs must be sorted ascending")
  end)
end)
