local support = require("TestSupport")
local default_map = require("Config.Maps.DefaultMap")
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

return {
  name = "movement",
  tests = {
    { name = "pass_start", run = _test_pass_start },
    { name = "roadblock_stop", run = _test_roadblock_stop },
    { name = "movement_examples_from_issue", run = _test_movement_examples_from_issue },
    { name = "board_indices_in_range_uses_graph_distance", run = _test_board_indices_in_range_uses_graph_distance },
    { name = "movement_backward_wrap", run = _test_movement_backward_wrap },
    { name = "movement_fresh_roll_ignores_stale_move_dir", run = _test_movement_fresh_roll_ignores_stale_move_dir },
  },
}
