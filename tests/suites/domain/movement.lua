local support = require("support.domain_support")
local default_map = require("Config.maps.default_map")
local facing_policy = require("src.game.systems.board.facing_policy")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _assert_eq = support.assert_eq
local movement = support.movement
local board_utils = support.board_utils
local move_anim = require("src.presentation.view.render.move_anim")
local board_feedback = require("src.presentation.view.render.board_feedback_service")
local runtime_ports = require("src.core.ports.runtime_ports")

local function _simulate_heading(board, start_index, facing, steps, backward, parity)
  local current = start_index
  local heading = facing
  local step_fn = backward and board.step_backward_by_facing or board.step_forward_by_facing
  for _ = 1, steps do
    local next_index, _, next_heading
    if backward then
      next_index, _, next_heading = step_fn(board, current, heading)
    else
      next_index, _, next_heading = step_fn(board, current, heading, parity)
    end
    current = next_index
    heading = next_heading
  end
  return current, heading
end

local function _test_pass_start()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(24))
  local res = movement.move(g, p, 1, { branch_parity = 1 })
  _assert_eq(res.passed_start, 1, "pass_start bonus")
end

local function _test_roadblock_stop()
  local g = _new_game()
  local p = g:current_player()
  g.board:place_roadblock(2)
  local res = movement.move(g, p, 3, { branch_parity = 3 })
  _assert_eq(res.stopped_on_roadblock, true, "stopped on roadblock")
  _assert_eq(p.position, 2, "position should stop at roadblock")
end

local function _test_movement_examples_from_issue()
  local g = _new_game()
  local p = g:current_player()

  g:update_player_position(p, g.board:index_of_tile_id(3))
  local r1 = movement.move(g, p, 4, { branch_parity = 4, skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 32, "example1 end tile")
  assert(#r1.visited == 4, "example1 visited steps")

  g:update_player_position(p, g.board:index_of_tile_id(32))
  local r2 = movement.move(g, p, 6, { branch_parity = 6, direction = "down", skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 6, "example2 end tile")
  assert(#r2.visited == 6, "example2 visited steps")

  g:update_player_position(p, g.board:index_of_tile_id(25))
  local r3 = movement.move(g, p, 12, { branch_parity = 12, direction = "right", skip_market_check = true })
  _assert_eq(g.board:get_tile(p.position).id, 7, "example3 end tile")
  assert(#r3.visited == 12, "example3 visited steps")
end

local function _test_board_indices_in_range_uses_graph_distance()
  local g = _new_game()
  local idx_a = g.board:index_of_tile_id(27)
  local idx_b = g.board:index_of_tile_id(28)
  assert(idx_a and idx_b, "expected tile ids 27/28")
  local list = board_utils.indices_in_range(g.board, idx_a, 1)
  for _, idx in ipairs(list) do
    assert(idx ~= idx_b, "graph distance should not include path neighbor")
  end
end

local function _test_movement_backward_wrap()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, 1)
  local res = movement.move(g, p, -1, { branch_parity = 1 })
  assert(p.position >= 1 and p.position <= g.board:length(), "backward index in range")
  assert(#res.visited == 1, "visited steps")
end

local function _test_movement_backward_from_hongkong_follows_three_unique_tiles()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, 7)
  g:set_player_status(p, "move_dir", "down")

  local res = movement.move(g, p, -3, { branch_parity = 1, skip_market_check = true })

  _assert_eq(p.position, 4, "backward move from hongkong should land on haikou")
  local names = {}
  for i, idx in ipairs(res.visited or {}) do
    local tile = assert(g.board:get_tile(idx), "missing visited tile: " .. tostring(idx))
    names[i] = tile.name
  end
  _assert_eq(names[1], "广州路", "backward step 1 should be guangzhou")
  _assert_eq(names[2], "道具卡", "backward step 2 should be item tile")
  _assert_eq(names[3], "海口路", "backward step 3 should be haikou")
  _assert_eq(p.status.move_dir, "down", "backward move should preserve the recorded forward heading")
end

local function _test_movement_backward_without_move_dir_keeps_nil()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  g:set_player_status(p, "move_dir", nil)

  local res = movement.move(g, p, -1, { branch_parity = 1, skip_market_check = true })

  assert(#res.visited == 1, "backward move should still record visited tiles")
  _assert_eq(p.status.move_dir, nil, "backward move without stored heading should keep nil")
end

local function _run_start_move_with_stale_dir(start_index, stale_dir)
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, start_index)
  g:set_player_status(p, "move_dir", stale_dir)
  local res = movement.move(g, p, 2, { branch_parity = 2, skip_market_check = true })
  return p.position, res
end

local function _test_movement_fresh_roll_ignores_stale_move_dir()
  local start_index = 34
  local left_end = _run_start_move_with_stale_dir(start_index, "left")
  local right_end = _run_start_move_with_stale_dir(start_index, "right")
  local up_end = _run_start_move_with_stale_dir(start_index, "up")

  _assert_eq(left_end, right_end, "fresh roll should not inherit stale horizontal direction")
  _assert_eq(right_end, up_end, "fresh roll should not inherit stale vertical direction")
end

local function _test_movement_single_step_sets_move_dir_to_next_heading()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  local res = movement.move(g, p, 1, { branch_parity = 1, skip_market_check = true })
  assert(#res.visited == 1, "single-step move should record exactly one visited index")
  local _, expected = _simulate_heading(g.board, g.board:index_of_tile_id(42), nil, 1, false, 1)
  _assert_eq(p.status.move_dir, expected, "single-step move_dir should keep the next forward heading")
end

local function _test_movement_multi_step_sets_move_dir_to_next_heading()
  local g = _new_game()
  local p = g:current_player()
  local start_index = g.board:index_of_tile_id(3)
  g:update_player_position(p, start_index)
  local steps = 4
  local parity = 4
  local res = movement.move(g, p, steps, { branch_parity = parity, skip_market_check = true })
  assert(#res.visited == 4, "multi-step move should record every visited index")
  local _, expected = _simulate_heading(g.board, start_index, nil, steps, false, parity)
  _assert_eq(p.status.move_dir, expected, "multi-step move_dir should keep the next forward heading")
end

local function _test_entry_point_even_branch_requires_matching_inbound_facing()
  local g = _new_game()
  local entry_idx = g.board:index_of_tile_id(42)

  local matching_idx, _, matching_dir = g.board:step_forward_by_facing(entry_idx, "left", 2)
  local matching_tile = assert(g.board:get_tile(matching_idx), "missing matching branch tile")
  _assert_eq(matching_tile.id, 45, "matching inbound facing should enter inner branch")
  _assert_eq(matching_dir, "up", "matching branch should return the next heading after entering inner branch")

  local mismatched_idx, _, mismatched_dir = g.board:step_forward_by_facing(entry_idx, "right", 2)
  local mismatched_tile = assert(g.board:get_tile(mismatched_idx), "missing outer path tile")
  _assert_eq(mismatched_tile.id, 4, "mismatched inbound facing should stay on outer path")
  _assert_eq(mismatched_dir, "left", "outer fallback should return the next heading on outer path")
end

local function _test_market_exit_keeps_turn_parity_without_uturn()
  local g = _new_game()
  local market_idx = g.board:index_of_tile_id(g.board.map.market_id)

  local even_idx, _, even_dir = g.board:step_forward_by_facing(market_idx, "up", 2)
  local even_tile = assert(g.board:get_tile(even_idx), "missing even market exit tile")
  _assert_eq(even_tile.id, 44, "even parity should turn right from market")
  _assert_eq(even_dir, "right", "even parity should report the next heading after the market exit")

  local odd_idx, _, odd_dir = g.board:step_forward_by_facing(market_idx, "up", 1)
  local odd_tile = assert(g.board:get_tile(odd_idx), "missing odd market exit tile")
  _assert_eq(odd_tile.id, 27, "odd parity should turn left from market")
  _assert_eq(odd_dir, "left", "odd parity should report the next heading after the market exit")
end

local function _test_inner_ring_fresh_roll_defaults_toward_market()
  local g = _new_game()
  local p = g:current_player()
  local cases = {
    { start_tile_id = 25, steps = 1, expected_tile_id = 26 },
    { start_tile_id = 30, steps = 1, expected_tile_id = 29 },
    { start_tile_id = 34, steps = 1, expected_tile_id = 33 },
    { start_tile_id = 45, steps = 1, expected_tile_id = 31 },
    { start_tile_id = 28, steps = 4, expected_tile_id = 25 },
  }

  for _, case in ipairs(cases) do
    g:update_player_position(p, g.board:index_of_tile_id(case.start_tile_id))
    g:set_player_status(p, "move_dir", nil)
    local res = movement.move(g, p, case.steps, {
      branch_parity = case.steps,
      skip_market_check = true,
    })
    local landing_tile = assert(res.landing_tile, "fresh inner roll should land on a tile")
    _assert_eq(landing_tile.id, case.expected_tile_id,
      "fresh inner roll should follow market-facing default from tile " .. tostring(case.start_tile_id))
  end
end

local function _test_resume_forward_from_inner_ring_keeps_explicit_direction()
  local g = _new_game()
  local p = g:current_player()

  g:update_player_position(p, g.board:index_of_tile_id(28))
  g:set_player_status(p, "move_dir", nil)

  local res = movement.move(g, p, 4, {
    branch_parity = 4,
    direction = "up",
    facing_mode = "resume_forward",
    skip_market_check = true,
  })

  local landing_tile = assert(res.landing_tile, "resume move should land on a tile")
  _assert_eq(landing_tile.id, 16, "resume_forward should preserve the explicit continuation away from market")
end

local function _test_resume_forward_requires_explicit_direction()
  local g = _new_game()
  local p = g:current_player()
  local ok, err = pcall(function()
    facing_policy.resolve_initial_facing("resume_forward", p, {})
  end)
  assert(ok == false, "resume_forward should reject missing opts.direction")
  assert(tostring(err):find("resume_forward requires opts.direction", 1, true) ~= nil,
    "resume_forward should report the missing direction contract")
end

local function _test_move_anim_play_sequence_emits_step_sound_per_visited_tile()
  local calls = {}
  local step_calls = {}
  local scheduled = {}
  local board_scene = { tiles = {}, units_by_player_id = {} }
  local state = { board_scene = board_scene }

  support.with_patches({
    {
      target = move_anim,
      key = "step_duration",
      value = function()
        return 0.1
      end,
    },
    {
      target = move_anim,
      key = "one_step",
      value = function(_, player_id, from_index, to_index)
        step_calls[#step_calls + 1] = { player_id = player_id, from_index = from_index, to_index = to_index }
        return 0.1
      end,
    },
    {
      target = board_feedback,
      key = "play_step_tile_sound",
      value = function(_, player_id, tile_index)
        calls[#calls + 1] = { player_id = player_id, tile_index = tile_index }
        return true
      end,
    },
    {
      target = runtime_ports,
      key = "schedule",
      value = function(delay, fn)
        scheduled[#scheduled + 1] = { delay = delay, fn = fn }
        return true
      end,
    },
  }, function()
    local total = move_anim.play_sequence(board_scene, {
      state = state,
      player_id = 1,
      from_index = 1,
      to_index = 4,
      visited = { 2, 3, 4 },
      direction = "left",
    })
    assert(math.abs(total - 0.3) < 0.0001, "three steps should sum patched step duration")
    table.sort(scheduled, function(a, b)
      return a.delay < b.delay
    end)
    for _, entry in ipairs(scheduled) do
      entry.fn()
    end
  end)

  assert(#calls == 3, "move sequence should emit one step sound per visited tile")
  _assert_eq(calls[1].tile_index, 2, "step sound should target first visited tile")
  _assert_eq(calls[2].tile_index, 3, "step sound should target second visited tile")
  _assert_eq(calls[3].tile_index, 4, "step sound should target final visited tile")
  assert(#step_calls == 3, "move sequence should still execute three steps")
end

-- Characterization tests for board helper functions (T4)
local Board = require("src.game.systems.board.init")

local function _test_resolve_outer_next_returns_outer_next_when_no_entry()
  local map = {
    outer_next = { [1] = 2 },
    entry_points = {},
    outer_prev = {},
    direction = function() return "up" end,
  }
  local result = Board._resolve_outer_next(map, 1, "up", 1)
  _assert_eq(result, 2, "should return outer_next when no entry point")
end

local function _test_resolve_outer_next_returns_inner_on_even_parity_with_matching_facing()
  -- The logic: if direction(prev_id, current_id) == facing, use inner_id
  -- This means the player is coming from the direction they're facing (continuing forward)
  -- Note: map.direction is called as map.direction(prev_id, current_id) - no self param
  local map = {
    outer_next = { [1] = 2 },
    entry_points = { [1] = { inner_id = 10 } },
    outer_prev = { [1] = 99 },
    direction = function(from, to)
      -- When coming from 99 to 1, if facing is "up", direction should return "up" for match
      if from == 99 and to == 1 then return "up" end
      return "down"
    end,
  }
  -- When facing="up" and direction(99, 1)="up" (matching), should return inner_id
  local result = Board._resolve_outer_next(map, 1, "up", 2)
  _assert_eq(result, 10, "should return inner_id on even parity with matching facing")
end

local function _test_resolve_outer_next_returns_outer_on_even_parity_with_mismatched_facing()
  -- The logic: if direction(prev_id, current_id) ~= facing, use outer_next
  -- This means the player is coming from a different direction than they're facing
  local map = {
    outer_next = { [1] = 2 },
    entry_points = { [1] = { inner_id = 10 } },
    outer_prev = { [1] = 99 },
    direction = function(from, to)
      -- When coming from 99 to 1, if facing is "up", direction returns "down" for mismatch
      if from == 99 and to == 1 then return "down" end
      return "up"
    end,
  }
  -- When facing="up" and direction(99, 1)="down" (mismatch), should return outer_next
  local result = Board._resolve_outer_next(map, 1, "up", 2)
  _assert_eq(result, 2, "should return outer_next on even parity with mismatched facing")
end

local function _test_resolve_outer_next_returns_nil_when_no_outer_next()
  local map = {
    outer_next = {},
    entry_points = {},
    outer_prev = {},
  }
  local result = Board._resolve_outer_next(map, 1, "up", 1)
  _assert_eq(result, nil, "should return nil when no outer_next")
end

local function _test_resolve_fresh_forward_next_returns_fresh_next_when_facing_nil()
  local map = {
    fresh_forward_next = { [1] = 5 },
  }
  local result = Board._resolve_fresh_forward_next(map, 1, nil)
  _assert_eq(result, 5, "should return fresh_forward_next when facing is nil")
end

local function _test_resolve_fresh_forward_next_returns_nil_when_facing_not_nil()
  local map = {
    fresh_forward_next = { [1] = 5 },
  }
  local result = Board._resolve_fresh_forward_next(map, 1, "up")
  _assert_eq(result, nil, "should return nil when facing is not nil")
end

local function _test_resolve_fresh_forward_next_returns_nil_when_no_fresh_forward_next()
  local map = {}
  local result = Board._resolve_fresh_forward_next(map, 1, nil)
  _assert_eq(result, nil, "should return nil when no fresh_forward_next")
end

local function _test_resolve_market_exit_returns_turn_right_on_even_parity()
  local map = {
    market_id = 5,
    turn_right = { up = "right" },
    turn_left = { up = "left" },
  }
  local neigh = { right = 10, left = 20, up = 30 }
  local result = Board._resolve_market_exit(map, 5, neigh, "up", 2)
  _assert_eq(result, 10, "should return turn_right direction on even parity")
end

local function _test_resolve_market_exit_returns_turn_left_on_odd_parity()
  local map = {
    market_id = 5,
    turn_right = { up = "right" },
    turn_left = { up = "left" },
  }
  local neigh = { right = 10, left = 20, up = 30 }
  local result = Board._resolve_market_exit(map, 5, neigh, "up", 1)
  _assert_eq(result, 20, "should return turn_left direction on odd parity")
end

local function _test_resolve_market_exit_returns_facing_when_exit_dir_nil()
  local map = {
    market_id = 5,
    turn_right = { up = nil },
    turn_left = { up = "left" },
  }
  local neigh = { right = 10, left = 20, up = 30 }
  local result = Board._resolve_market_exit(map, 5, neigh, "up", 2)
  _assert_eq(result, 30, "should return facing direction when exit_dir is nil but facing exists")
end

local function _test_resolve_market_exit_returns_nil_when_not_market()
  local map = {
    market_id = 5,
    turn_right = {},
    turn_left = {},
  }
  local neigh = {}
  local result = Board._resolve_market_exit(map, 1, neigh, "up", 1)
  _assert_eq(result, nil, "should return nil when current_id is not market_id")
end

local function _test_resolve_market_exit_returns_nil_when_facing_nil()
  local map = {
    market_id = 5,
    turn_right = {},
    turn_left = {},
  }
  local neigh = {}
  local result = Board._resolve_market_exit(map, 5, neigh, nil, 1)
  _assert_eq(result, nil, "should return nil when facing is nil")
end

local function _test_resolve_facing_next_returns_neighbor_in_facing_direction()
  local neigh = { up = 10, down = 20, left = 30, right = 40 }
  local result = Board._resolve_facing_next(neigh, "up")
  _assert_eq(result, 10, "should return neighbor in facing direction")
end

local function _test_resolve_facing_next_returns_nil_when_no_facing()
  local neigh = { up = 10 }
  local result = Board._resolve_facing_next(neigh, nil)
  _assert_eq(result, nil, "should return nil when facing is nil")
end

local function _test_resolve_facing_next_returns_nil_when_no_neighbor_in_facing()
  local neigh = { up = 10 }
  local result = Board._resolve_facing_next(neigh, "down")
  _assert_eq(result, nil, "should return nil when no neighbor in facing direction")
end

local function _test_resolve_fallback_next_returns_unique_dir_avoiding_back()
  -- When facing="up", back_dir="down" (opposite)
  -- neigh has "up" and "down", avoiding "down" leaves only "up"
  local neigh = { up = 10, down = 20 }
  local result = Board._resolve_fallback_next(neigh, "up")
  _assert_eq(result, 10, "should return unique dir avoiding back direction (down)")
end

local function _test_resolve_fallback_next_returns_any_dir_avoiding_back_when_not_unique()
  -- When facing="up", back_dir="down"
  -- neigh has up=10, down=20, left=30 - avoiding "down" leaves "up" and "left"
  -- Since there are multiple options, _pick_unique_dir returns nil
  -- Then _pick_any_dir is called which returns the first sorted dir (left before up)
  local neigh = { up = 10, down = 20, left = 30 }
  local result = Board._resolve_fallback_next(neigh, "up")
  assert(result ~= nil, "should return some direction when multiple options")
  assert(result ~= 20, "should not return back direction (down)")
end

local function _test_resolve_fallback_next_returns_any_dir_when_back_nil()
  local neigh = { up = 10 }
  local result = Board._resolve_fallback_next(neigh, nil)
  _assert_eq(result, 10, "should return any dir when back direction is nil")
end

local function _test_pick_any_dir_returns_first_sorted_dir()
  local neigh = { right = 10, up = 20, down = 30 }
  local dir, id = Board._pick_any_dir(neigh, nil)
  _assert_eq(dir, "up", "should return first sorted dir (up before right before down)")
  _assert_eq(id, 20, "should return id for that dir")
end

local function _test_pick_any_dir_avoids_avoid_dir()
  local neigh = { up = 10, down = 20 }
  local dir, id = Board._pick_any_dir(neigh, "up")
  _assert_eq(dir, "down", "should avoid the specified dir")
  _assert_eq(id, 20, "should return id for non-avoided dir")
end

local function _test_pick_any_dir_returns_nil_when_all_avoided()
  local neigh = { up = 10 }
  local dir, id = Board._pick_any_dir(neigh, "up")
  _assert_eq(dir, nil, "should return nil dir when all avoided")
  _assert_eq(id, nil, "should return nil id when all avoided")
end

local function _test_pick_unique_dir_returns_unique_when_only_one_option()
  local neigh = { up = 10 }
  local dir, id = Board._pick_unique_dir(neigh, nil)
  _assert_eq(dir, "up", "should return unique dir")
  _assert_eq(id, 10, "should return unique id")
end

local function _test_pick_unique_dir_returns_nil_when_multiple_options()
  local neigh = { up = 10, down = 20 }
  local dir, id = Board._pick_unique_dir(neigh, nil)
  _assert_eq(dir, nil, "should return nil when multiple options")
  _assert_eq(id, nil, "should return nil id when multiple options")
end

local function _test_pick_unique_dir_returns_unique_when_others_avoided()
  local neigh = { up = 10, down = 20 }
  local dir, id = Board._pick_unique_dir(neigh, "up")
  _assert_eq(dir, "down", "should return unique non-avoided dir")
  _assert_eq(id, 20, "should return id for unique non-avoided dir")
end

-- Characterization tests for board_query helper functions (T4)
local board_query = require("src.game.systems.board.query")

local function _test_bfs_collect_indices_returns_empty_for_zero_distance()
  local g = _new_game()
  local start_tile = g.board:get_tile(1)
  local by_dist = board_query._bfs_collect_indices(g.board, g.board.map.neighbors, start_tile.id, 0)
  assert(type(by_dist) == "table", "should return a table")
  assert(next(by_dist) == nil, "should return empty table for max_dist=0")
end

local function _test_bfs_collect_indices_finds_neighbors_at_distance_one()
  local g = _new_game()
  local start_idx = g.board:index_of_tile_id(1)
  local start_tile = g.board:get_tile(start_idx)
  local by_dist = board_query._bfs_collect_indices(g.board, g.board.map.neighbors, start_tile.id, 1)
  assert(by_dist[1] ~= nil, "should have entries at distance 1")
  assert(#by_dist[1] > 0, "should find at least one neighbor at distance 1")
end

local function _test_bfs_collect_indices_does_not_exceed_max_dist()
  local g = _new_game()
  local start_idx = g.board:index_of_tile_id(1)
  local start_tile = g.board:get_tile(start_idx)
  local by_dist = board_query._bfs_collect_indices(g.board, g.board.map.neighbors, start_tile.id, 2)
  assert(by_dist[3] == nil, "should not have entries beyond max_dist")
  assert(by_dist[4] == nil, "should not have entries beyond max_dist")
end

local function _test_bfs_collect_indices_avoids_revisiting_tiles()
  local g = _new_game()
  local start_idx = g.board:index_of_tile_id(1)
  local start_tile = g.board:get_tile(start_idx)
  local seen = {}
  local by_dist = board_query._bfs_collect_indices(g.board, g.board.map.neighbors, start_tile.id, 3)
  for dist, indices in pairs(by_dist) do
    for _, idx in ipairs(indices) do
      assert(seen[idx] == nil, "tile " .. tostring(idx) .. " should not be visited twice")
      seen[idx] = dist
    end
  end
end

local function _test_flatten_by_distance_returns_empty_for_empty_input()
  local result = board_query._flatten_by_distance({}, 3)
  assert(type(result) == "table", "should return a table")
  assert(#result == 0, "should return empty list for empty input")
end

local function _test_flatten_by_distance_orders_by_distance()
  local by_dist = {
    [1] = { 10, 11 },
    [2] = { 20, 21 },
    [3] = { 30 },
  }
  local result = board_query._flatten_by_distance(by_dist, 3)
  _assert_eq(#result, 5, "should return all entries")
  _assert_eq(result[1], 10, "first entry should be from distance 1")
  _assert_eq(result[2], 11, "second entry should be from distance 1")
  _assert_eq(result[3], 20, "third entry should be from distance 2")
  _assert_eq(result[4], 21, "fourth entry should be from distance 2")
  _assert_eq(result[5], 30, "fifth entry should be from distance 3")
end

local function _test_flatten_by_distance_skips_missing_distances()
  local by_dist = {
    [1] = { 10 },
    [3] = { 30 },
  }
  local result = board_query._flatten_by_distance(by_dist, 3)
  _assert_eq(#result, 2, "should return only existing entries")
  _assert_eq(result[1], 10, "first entry should be from distance 1")
  _assert_eq(result[2], 30, "second entry should be from distance 3")
end

local function _test_flatten_by_distance_handles_max_dist_greater_than_entries()
  local by_dist = {
    [1] = { 10 },
  }
  local result = board_query._flatten_by_distance(by_dist, 5)
  _assert_eq(#result, 1, "should return only existing entries even when max_dist is larger")
end

return {
  name = "movement",
  tests = {
    { name = "pass_start", run = _test_pass_start },
    { name = "roadblock_stop", run = _test_roadblock_stop },
    { name = "movement_examples_from_issue", run = _test_movement_examples_from_issue },
    { name = "board_indices_in_range_uses_graph_distance", run = _test_board_indices_in_range_uses_graph_distance },
    { name = "movement_backward_wrap", run = _test_movement_backward_wrap },
    { name = "movement_backward_from_hongkong_follows_three_unique_tiles", run = _test_movement_backward_from_hongkong_follows_three_unique_tiles },
    { name = "movement_backward_without_move_dir_keeps_nil", run = _test_movement_backward_without_move_dir_keeps_nil },
    { name = "movement_fresh_roll_ignores_stale_move_dir", run = _test_movement_fresh_roll_ignores_stale_move_dir },
    { name = "movement_single_step_sets_move_dir_to_next_heading", run = _test_movement_single_step_sets_move_dir_to_next_heading },
    { name = "movement_multi_step_sets_move_dir_to_next_heading", run = _test_movement_multi_step_sets_move_dir_to_next_heading },
    { name = "entry_point_even_branch_requires_matching_inbound_facing", run = _test_entry_point_even_branch_requires_matching_inbound_facing },
    { name = "market_exit_keeps_turn_parity_without_uturn", run = _test_market_exit_keeps_turn_parity_without_uturn },
    { name = "inner_ring_fresh_roll_defaults_toward_market", run = _test_inner_ring_fresh_roll_defaults_toward_market },
    { name = "resume_forward_from_inner_ring_keeps_explicit_direction", run = _test_resume_forward_from_inner_ring_keeps_explicit_direction },
    { name = "resume_forward_requires_explicit_direction", run = _test_resume_forward_requires_explicit_direction },
    { name = "move_anim_play_sequence_emits_step_sound_per_visited_tile", run = _test_move_anim_play_sequence_emits_step_sound_per_visited_tile },
    -- Board helper characterization tests (T4)
    { name = "resolve_outer_next_returns_outer_next_when_no_entry", run = _test_resolve_outer_next_returns_outer_next_when_no_entry },
    { name = "resolve_outer_next_returns_inner_on_even_parity_with_matching_facing", run = _test_resolve_outer_next_returns_inner_on_even_parity_with_matching_facing },
    { name = "resolve_outer_next_returns_outer_on_even_parity_with_mismatched_facing", run = _test_resolve_outer_next_returns_outer_on_even_parity_with_mismatched_facing },
    { name = "resolve_outer_next_returns_nil_when_no_outer_next", run = _test_resolve_outer_next_returns_nil_when_no_outer_next },
    { name = "resolve_fresh_forward_next_returns_fresh_next_when_facing_nil", run = _test_resolve_fresh_forward_next_returns_fresh_next_when_facing_nil },
    { name = "resolve_fresh_forward_next_returns_nil_when_facing_not_nil", run = _test_resolve_fresh_forward_next_returns_nil_when_facing_not_nil },
    { name = "resolve_fresh_forward_next_returns_nil_when_no_fresh_forward_next", run = _test_resolve_fresh_forward_next_returns_nil_when_no_fresh_forward_next },
    { name = "resolve_market_exit_returns_turn_right_on_even_parity", run = _test_resolve_market_exit_returns_turn_right_on_even_parity },
    { name = "resolve_market_exit_returns_turn_left_on_odd_parity", run = _test_resolve_market_exit_returns_turn_left_on_odd_parity },
    { name = "resolve_market_exit_returns_facing_when_exit_dir_nil", run = _test_resolve_market_exit_returns_facing_when_exit_dir_nil },
    { name = "resolve_market_exit_returns_nil_when_not_market", run = _test_resolve_market_exit_returns_nil_when_not_market },
    { name = "resolve_market_exit_returns_nil_when_facing_nil", run = _test_resolve_market_exit_returns_nil_when_facing_nil },
    { name = "resolve_facing_next_returns_neighbor_in_facing_direction", run = _test_resolve_facing_next_returns_neighbor_in_facing_direction },
    { name = "resolve_facing_next_returns_nil_when_no_facing", run = _test_resolve_facing_next_returns_nil_when_no_facing },
    { name = "resolve_facing_next_returns_nil_when_no_neighbor_in_facing", run = _test_resolve_facing_next_returns_nil_when_no_neighbor_in_facing },
    { name = "resolve_fallback_next_returns_unique_dir_avoiding_back", run = _test_resolve_fallback_next_returns_unique_dir_avoiding_back },
    { name = "resolve_fallback_next_returns_any_dir_avoiding_back_when_not_unique", run = _test_resolve_fallback_next_returns_any_dir_avoiding_back_when_not_unique },
    { name = "resolve_fallback_next_returns_any_dir_when_back_nil", run = _test_resolve_fallback_next_returns_any_dir_when_back_nil },
    { name = "pick_any_dir_returns_first_sorted_dir", run = _test_pick_any_dir_returns_first_sorted_dir },
    { name = "pick_any_dir_avoids_avoid_dir", run = _test_pick_any_dir_avoids_avoid_dir },
    { name = "pick_any_dir_returns_nil_when_all_avoided", run = _test_pick_any_dir_returns_nil_when_all_avoided },
    { name = "pick_unique_dir_returns_unique_when_only_one_option", run = _test_pick_unique_dir_returns_unique_when_only_one_option },
    { name = "pick_unique_dir_returns_nil_when_multiple_options", run = _test_pick_unique_dir_returns_nil_when_multiple_options },
    { name = "pick_unique_dir_returns_unique_when_others_avoided", run = _test_pick_unique_dir_returns_unique_when_others_avoided },
    -- Board_query helper characterization tests (T4)
    { name = "bfs_collect_indices_returns_empty_for_zero_distance", run = _test_bfs_collect_indices_returns_empty_for_zero_distance },
    { name = "bfs_collect_indices_finds_neighbors_at_distance_one", run = _test_bfs_collect_indices_finds_neighbors_at_distance_one },
    { name = "bfs_collect_indices_does_not_exceed_max_dist", run = _test_bfs_collect_indices_does_not_exceed_max_dist },
    { name = "bfs_collect_indices_avoids_revisiting_tiles", run = _test_bfs_collect_indices_avoids_revisiting_tiles },
    { name = "flatten_by_distance_returns_empty_for_empty_input", run = _test_flatten_by_distance_returns_empty_for_empty_input },
    { name = "flatten_by_distance_orders_by_distance", run = _test_flatten_by_distance_orders_by_distance },
    { name = "flatten_by_distance_skips_missing_distances", run = _test_flatten_by_distance_skips_missing_distances },
    { name = "flatten_by_distance_handles_max_dist_greater_than_entries", run = _test_flatten_by_distance_handles_max_dist_greater_than_entries },
  },
}
