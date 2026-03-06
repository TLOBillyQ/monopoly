local support = require("TestSupport")
local default_map = require("Config.Maps.DefaultMap")
local facing_policy = require("src.game.systems.board.FacingPolicy")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _assert_eq = support.assert_eq
local movement = support.movement
local board_utils = support.board_utils

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

local function _assert_last_move_dir_matches_edge(game, visited, move_dir, msg)
  local current_idx = visited[#visited]
  local prev_idx = visited[#visited - 1]
  local current_tile = assert(game.board:get_tile(current_idx), "missing current tile")
  local prev_tile = assert(game.board:get_tile(prev_idx), "missing previous tile")
  local expected = game.board.map.direction(prev_tile.id, current_tile.id)
  _assert_eq(move_dir, expected, msg)
end

local function _test_movement_single_step_sets_move_dir_to_traversed_edge()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(42))
  local start_tile = assert(g.board:get_tile(p.position), "missing start tile")
  local res = movement.move(g, p, 1, { branch_parity = 1, skip_market_check = true })
  assert(#res.visited == 1, "single-step move should record exactly one visited index")
  local landing_tile = assert(g.board:get_tile(p.position), "missing landing tile")
  local expected = g.board.map.direction(start_tile.id, landing_tile.id)
  _assert_eq(p.status.move_dir, expected, "single-step move_dir should match traversed edge")
end

local function _test_movement_multi_step_sets_move_dir_to_last_traversed_edge()
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, g.board:index_of_tile_id(3))
  local res = movement.move(g, p, 4, { branch_parity = 4, skip_market_check = true })
  assert(#res.visited == 4, "multi-step move should record every visited index")
  _assert_last_move_dir_matches_edge(g, res.visited, p.status.move_dir, "multi-step move_dir should match last traversed edge")
end

local function _test_entry_point_even_branch_requires_matching_inbound_facing()
  local g = _new_game()
  local entry_idx = g.board:index_of_tile_id(42)

  local matching_idx, _, matching_dir = g.board:step_forward_by_facing(entry_idx, "left", 2)
  local matching_tile = assert(g.board:get_tile(matching_idx), "missing matching branch tile")
  _assert_eq(matching_tile.id, 45, "matching inbound facing should enter inner branch")
  _assert_eq(matching_dir, "up", "matching branch should return traversed inner edge direction")

  local mismatched_idx, _, mismatched_dir = g.board:step_forward_by_facing(entry_idx, "right", 2)
  local mismatched_tile = assert(g.board:get_tile(mismatched_idx), "missing outer path tile")
  _assert_eq(mismatched_tile.id, 4, "mismatched inbound facing should stay on outer path")
  _assert_eq(mismatched_dir, "left", "outer fallback should return traversed outer edge direction")
end

local function _test_market_exit_keeps_turn_parity_without_uturn()
  local g = _new_game()
  local market_idx = g.board:index_of_tile_id(g.board.map.market_id)

  local even_idx, _, even_dir = g.board:step_forward_by_facing(market_idx, "up", 2)
  local even_tile = assert(g.board:get_tile(even_idx), "missing even market exit tile")
  _assert_eq(even_tile.id, 44, "even parity should turn right from market")
  _assert_eq(even_dir, "right", "even parity should report actual right-turn edge")

  local odd_idx, _, odd_dir = g.board:step_forward_by_facing(market_idx, "up", 1)
  local odd_tile = assert(g.board:get_tile(odd_idx), "missing odd market exit tile")
  _assert_eq(odd_tile.id, 27, "odd parity should turn left from market")
  _assert_eq(odd_dir, "left", "odd parity should report actual left-turn edge")
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

return {
  name = "movement",
  tests = {
    { name = "pass_start", run = _test_pass_start },
    { name = "roadblock_stop", run = _test_roadblock_stop },
    { name = "movement_examples_from_issue", run = _test_movement_examples_from_issue },
    { name = "board_indices_in_range_uses_graph_distance", run = _test_board_indices_in_range_uses_graph_distance },
    { name = "movement_backward_wrap", run = _test_movement_backward_wrap },
    { name = "movement_fresh_roll_ignores_stale_move_dir", run = _test_movement_fresh_roll_ignores_stale_move_dir },
    { name = "movement_single_step_sets_move_dir_to_traversed_edge", run = _test_movement_single_step_sets_move_dir_to_traversed_edge },
    { name = "movement_multi_step_sets_move_dir_to_last_traversed_edge", run = _test_movement_multi_step_sets_move_dir_to_last_traversed_edge },
    { name = "entry_point_even_branch_requires_matching_inbound_facing", run = _test_entry_point_even_branch_requires_matching_inbound_facing },
    { name = "market_exit_keeps_turn_parity_without_uturn", run = _test_market_exit_keeps_turn_parity_without_uturn },
    { name = "resume_forward_requires_explicit_direction", run = _test_resume_forward_requires_explicit_direction },
  },
}
