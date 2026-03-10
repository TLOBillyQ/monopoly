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
  },
}
