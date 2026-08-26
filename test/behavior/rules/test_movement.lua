-- luacheck: ignore 211
local lu = require("luaunit")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local facing_policy = require("src.rules.board.facing_policy")
local function _new_game()
  return support.new_game({ map = default_map })
end
local _assert_eq = support.assert_eq
local _assert_player_move_dir = support.assert_player_move_dir
local movement = require("src.rules.movement")
local board_utils = require("src.rules.land.board_utils")
local move_anim = require("src.ui.render.move_anim")
local board_feedback = require("src.ui.render.board_feedback.service")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local move_anim_support = require("test.support.move_anim_support")
local timing = require("src.config.gameplay.timing")
local constants = require("src.config.content.constants")

local function _simulate_path_result(board, start_index, facing, steps, backward, parity)
  local current = start_index
  local next_facing = facing
  local step_fn = backward and board.step_backward_by_facing or board.step_forward_by_facing
  local entered_inner = false
  local start_tile = board:get_tile(start_index)
  if start_tile and board.map and board.map.outer_next and board.map.outer_next[start_tile.id] == nil then
    entered_inner = true
  end
  for _ = 1, steps do
    local next_index, _, resolved_next_facing
    if backward then
      next_index, _, resolved_next_facing = step_fn(board, current, next_facing)
    else
      local step_entered_inner
      next_index, _, resolved_next_facing, step_entered_inner = step_fn(board, current, next_facing, {
        parity = parity,
        entered_inner = entered_inner,
      })
      if step_entered_inner then
        entered_inner = true
      end
    end
    current = next_index
    next_facing = resolved_next_facing
  end
  return current, next_facing
end

local function _run_start_move_with_stale_dir(start_index, stale_dir)
  local g = _new_game()
  local p = g:current_player()
  g:update_player_position(p, start_index)
  g:set_player_status(p, "move_dir", stale_dir)
  local res = movement.move(g, p, 2, { branch_parity = 2, skip_market_check = true })
  return p.position, res
end

do -- describe("movement")
  local _config_reset = require("test.support.config_reset")

  TestMovement = {}

  function TestMovement:setUp()
    _config_reset.reset_all()
  end

  function TestMovement:test_pass_start_hold_schedules_settlement_with_step_based_delay(self)
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(24))
    local cash_before = g:player_cash(p)
    local scheduled = move_anim_support.capture_scheduled_callbacks(function()
      local res = movement.move(g, p, 1, { branch_parity = 1 })
      _assert_eq(res.passed_start, 1, "passed_start in result stays immediate for transit dedup")
    end)
    _assert_eq(#scheduled, 1, "exactly one schedule call for pass_start hold")
    _assert_eq(
      scheduled[1].delay,
      1 * timing.pass_start_hold_seconds_per_step + timing.pass_start_hold_tail_seconds,
      "delay = first_pass_step * per_step + tail"
    )
    _assert_eq(g:player_cash(p), cash_before, "cash held until scheduled callback runs")
    scheduled[1].fn()
    _assert_eq(g:player_cash(p), cash_before + constants.pass_start_bonus, "cash applied after callback runs")
  end

  function TestMovement:test_pass_start_hold_opts_override_skips_schedule(self)
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(24))
    local cash_before = g:player_cash(p)
    local scheduled = move_anim_support.capture_scheduled_callbacks(function()
      movement.move(g, p, 1, { branch_parity = 1, pass_start_hold_seconds = 0 })
    end)
    _assert_eq(#scheduled, 0, "no schedule call when override is 0")
    _assert_eq(g:player_cash(p), cash_before + constants.pass_start_bonus, "cash applied immediately on override")
  end

  function TestMovement:test_pass_start_hold_negative_override_settles_immediately(self)
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(24))
    local cash_before = g:player_cash(p)
    local scheduled = move_anim_support.capture_scheduled_callbacks(function()
      movement.move(g, p, 1, { branch_parity = 1, pass_start_hold_seconds = -5 })
    end)
    _assert_eq(#scheduled, 0, "a negative hold override should clamp to zero and skip scheduling")
    _assert_eq(g:player_cash(p), cash_before + constants.pass_start_bonus,
      "a negative override should settle the pass-start bonus immediately")
  end

  function TestMovement:test_pass_start_hold_skips_when_no_pass(self)
    local g = _new_game()
    local p = g:current_player()
    local cash_before = g:player_cash(p)
    local scheduled = move_anim_support.capture_scheduled_callbacks(function()
      local res = movement.move(g, p, 1, { branch_parity = 1 })
      _assert_eq(res.passed_start, 0, "no pass_start when not crossing start")
    end)
    _assert_eq(#scheduled, 0, "no schedule call when nothing to settle")
    _assert_eq(g:player_cash(p), cash_before, "cash unchanged")
  end

  function TestMovement:test_owner_mine_on_third_own_turn_stops_movement(self)
    local g = _new_game()
    local p = g:current_player()
    local mine_index = 2
    local placement_turn_started_count = 4
    g:set_player_status(p, "own_turn_started_count", placement_turn_started_count + 2)
    g.board:place_mine(mine_index, {
      owner_id = p.id,
      armed = true,
      owner_turn_started_count_at_placement = placement_turn_started_count,
    })

    local res = movement.move(g, p, 3, { branch_parity = 3, skip_market_check = true })

    _assert_eq(p.position, mine_index, "owner should trigger own mine starting from the third own turn")
    _assert_eq(#res.visited, 1, "owner third-turn self-trigger should stop movement on the mine tile")
  end

  function TestMovement:test_board_indices_in_range_uses_manhattan_distance(self)
    local g = _new_game()
    local start_idx = g.board:index_of_tile_id(1)
    local target_idx = g.board:index_of_tile_id(34)
    lu.assertEvalToTrue(start_idx and target_idx, "expected tile ids 1/34")
    local list = board_utils.indices_in_range(g.board, start_idx, 4)
    lu.assertEvalToTrue(support.list_contains(list, target_idx), "manhattan distance should include tiles within row/col radius")
  end

  function TestMovement:test_movement_backward_from_hongkong_follows_three_unique_tiles(self)
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
    _assert_player_move_dir(p, "down", "backward move should preserve the recorded forward heading")
  end

  function TestMovement:test_movement_backward_without_move_dir_keeps_nil(self)
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(42))
    g:set_player_status(p, "move_dir", nil)

    local res = movement.move(g, p, -1, { branch_parity = 1, skip_market_check = true })

    lu.assertEvalToTrue(#res.visited == 1, "backward move should still record visited tiles")
    _assert_player_move_dir(p, nil, "backward move without stored heading should keep nil")
  end

  function TestMovement:test_movement_fresh_roll_ignores_stale_move_dir(self)
    local g = _new_game()
    local start_index = g.board:index_of_tile_id(1)
    local left_end = _run_start_move_with_stale_dir(start_index, "left")
    local right_end = _run_start_move_with_stale_dir(start_index, "right")
    local up_end = _run_start_move_with_stale_dir(start_index, "up")

    _assert_eq(left_end, right_end, "fresh roll should not inherit stale horizontal direction")
    _assert_eq(right_end, up_end, "fresh roll should not inherit stale vertical direction")
  end

  function TestMovement:test_movement_single_step_sets_move_dir_to_next_heading(self)
    local g = _new_game()
    local p = g:current_player()
    g:update_player_position(p, g.board:index_of_tile_id(42))
    local res = movement.move(g, p, 1, { branch_parity = 1, skip_market_check = true })
    lu.assertEvalToTrue(#res.visited == 1, "single-step move should record exactly one visited index")
    local _, expected = _simulate_path_result(g.board, g.board:index_of_tile_id(42), nil, 1, false, 1)
    _assert_player_move_dir(p, expected, "single-step move_dir should keep the next forward heading")
  end

  function TestMovement:test_movement_multi_step_sets_move_dir_to_next_heading(self)
    local g = _new_game()
    local p = g:current_player()
    local start_index = g.board:index_of_tile_id(3)
    g:update_player_position(p, start_index)
    local steps = 4
    local parity = 4
    local res = movement.move(g, p, steps, { branch_parity = parity, skip_market_check = true })
    lu.assertEvalToTrue(#res.visited == 4, "multi-step move should record every visited index")
    local _, expected = _simulate_path_result(g.board, start_index, nil, steps, false, parity)
    _assert_player_move_dir(p, expected, "multi-step move_dir should keep the next forward heading")
  end

  function TestMovement:test_inner_exit_tiles_persist_outer_heading(self)
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, g.board:index_of_tile_id(30))
    movement.move(g, p, 1, { branch_parity = 1, skip_market_check = true, direction = "up" })
    _assert_player_move_dir(p, "right", "tile 41 should persist outer heading after leaving inner ring")

    g:update_player_position(p, g.board:index_of_tile_id(34))
    movement.move(g, p, 1, { branch_parity = 1, skip_market_check = true, direction = "right" })
    _assert_player_move_dir(p, "down", "tile 43 should persist outer heading after leaving inner ring")
  end

  function TestMovement:test_backward_from_exit_tiles_uses_outer_heading(self)
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, g.board:index_of_tile_id(41))
    g:set_player_status(p, "move_dir", "right")
    movement.move(g, p, -1, { branch_parity = 1, skip_market_check = true })
    _assert_eq(g.board:get_tile(p.position).id, 15, "tile 41 backward should follow outer heading")

    g:update_player_position(p, g.board:index_of_tile_id(43))
    g:set_player_status(p, "move_dir", "down")
    movement.move(g, p, -1, { branch_parity = 1, skip_market_check = true })
    _assert_eq(g.board:get_tile(p.position).id, 21, "tile 43 backward should follow outer heading")
  end

  function TestMovement:test_inner_backward_without_move_dir_uses_reverse_fallback(self)
    local g = _new_game()
    local p = g:current_player()
    local cases = {
      { start_tile_id = 45, expected_tile_id = 42 },
      { start_tile_id = 31, expected_tile_id = 45 },
      { start_tile_id = 32, expected_tile_id = 31 },
      { start_tile_id = 25, expected_tile_id = 40 },
      { start_tile_id = 26, expected_tile_id = 25 },
      { start_tile_id = 27, expected_tile_id = 26 },
      { start_tile_id = 28, expected_tile_id = 39 },
      { start_tile_id = 29, expected_tile_id = 28 },
      { start_tile_id = 30, expected_tile_id = 29 },
      { start_tile_id = 33, expected_tile_id = 44 },
      { start_tile_id = 34, expected_tile_id = 33 },
      { start_tile_id = 39, expected_tile_id = 27 },
      { start_tile_id = 44, expected_tile_id = 39 },
    }

    for _, case in ipairs(cases) do
      g:update_player_position(p, g.board:index_of_tile_id(case.start_tile_id))
      g:set_player_status(p, "move_dir", nil)
      movement.move(g, p, -1, { branch_parity = 1, skip_market_check = true })
      _assert_eq(g.board:get_tile(p.position).id, case.expected_tile_id,
        "inner nil move_dir backward fallback mismatch at tile " .. tostring(case.start_tile_id))
      _assert_player_move_dir(p, nil, "reverse fallback should not persist backward heading")
    end
  end

  function TestMovement:test_exit_inner_to_entry_tile_skips_reentering_next_turn(self)
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, g.board:index_of_tile_id(30))
    local exit_res = movement.move(g, p, 1, { branch_parity = 1, skip_market_check = true, direction = "up" })
    _assert_eq(assert(exit_res.landing_tile, "exit move should land on tile").id, 41,
      "inner exit should land on entry tile 41")
    lu.assertEvalToTrue(p.status and p.status.skip_next_inner_entry == true,
      "landing on entry tile right after exiting inner ring should arm skip-next-inner-entry")

    local next_res = movement.move(g, p, 2, { branch_parity = 2, skip_market_check = true })
    _assert_eq(assert(next_res.landing_tile, "next move should land on tile").id, 17,
      "next turn from tile 41 should stay on outer ring even on even parity")
    _assert_player_move_dir(p, "right", "outer continuation should keep outer heading on tile 17")
    lu.assertEvalToTrue(p.status and p.status.skip_next_inner_entry == false,
      "skip-next-inner-entry should be consumed after the next move starts on that entry tile")
  end

  function TestMovement:test_skip_next_inner_entry_only_blocks_current_entry_tile_once(self)
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, g.board:index_of_tile_id(41))
    g:set_player_status(p, "skip_next_inner_entry", true)
    local res = movement.move(g, p, 12, { branch_parity = 12, skip_market_check = true })

    _assert_eq(assert(res.landing_tile, "move should land on tile").id, 39,
      "same move should skip re-entry at starting tile 41 but still allow entering inner ring later at 43")
    lu.assertEvalToTrue(p.status and p.status.skip_next_inner_entry == false,
      "skip-next-inner-entry should clear after it is consumed")
  end

  function TestMovement:test_sync_move_dir_after_position_change_covers_core_modes(self)
    local g = _new_game()
    local p = g:current_player()

    g:set_player_status(p, "move_dir", "left")
    facing_policy.sync_move_dir_after_position_change(g, p, g.board:index_of_tile_id(3), "forced_move")
    _assert_player_move_dir(p, "left", "ordinary forced move should preserve move_dir")

    facing_policy.sync_move_dir_after_position_change(g, p, g.board:index_of_tile_id(39), "forced_move")
    _assert_player_move_dir(p, "right", "market forced move should use default heading")

    facing_policy.sync_move_dir_after_position_change(g, p, g.board:index_of_tile_id(36), "clear")
    _assert_player_move_dir(p, nil, "hospital sync mode should clear move_dir")

    g:set_player_status(p, "move_dir", "up")
    facing_policy.sync_move_dir_after_position_change(g, p, g.board:index_of_tile_id(37), "clear")
    _assert_player_move_dir(p, nil, "mountain sync mode should clear move_dir")
  end

  function TestMovement:test_market_keeps_forward_direction_regardless_of_parity(self)
    local g = _new_game()
    local market_idx = g.board:index_of_tile_id(g.board.map.market_id)

    local even_idx, _, even_next_facing = g.board:step_forward_by_facing(market_idx, "up", 2)
    local even_tile = assert(g.board:get_tile(even_idx), "missing even market exit tile")
    _assert_eq(even_tile.id, 28, "market should keep moving forward on even parity")
    _assert_eq(even_next_facing, "up", "market should keep the same heading on even parity")

    local odd_idx, _, odd_next_facing = g.board:step_forward_by_facing(market_idx, "up", 1)
    local odd_tile = assert(g.board:get_tile(odd_idx), "missing odd market exit tile")
    _assert_eq(odd_tile.id, 28, "market should keep moving forward on odd parity")
    _assert_eq(odd_next_facing, "up", "market should keep the same heading on odd parity")
  end

  function TestMovement:test_same_move_enters_inner_only_once(self)
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, g.board:index_of_tile_id(3))
    local res = movement.move(g, p, 10, { branch_parity = 10, skip_market_check = true })

    _assert_eq(g.board:get_tile(p.position).id, 16, "move should exit inner ring and continue on outer ring without re-entering")
    lu.assertEvalToTrue(#res.visited == 10, "same-move inner traversal should still record all steps")
  end

  function TestMovement:test_inner_ring_fresh_roll_keeps_saved_direction(self)
    local g = _new_game()
    local p = g:current_player()
    local cases = {
      { start_tile_id = 25, move_dir = "right", steps = 1, expected_tile_id = 26 },
      { start_tile_id = 30, move_dir = "up", steps = 1, expected_tile_id = 41 },
      { start_tile_id = 34, move_dir = "right", steps = 1, expected_tile_id = 43 },
      { start_tile_id = 45, move_dir = "up", steps = 1, expected_tile_id = 31 },
      { start_tile_id = 28, move_dir = "up", steps = 4, expected_tile_id = 16 },
      { start_tile_id = 28, move_dir = "down", steps = 4, expected_tile_id = 45 },
    }

    for _, case in ipairs(cases) do
      g:update_player_position(p, g.board:index_of_tile_id(case.start_tile_id))
      g:set_player_status(p, "move_dir", case.move_dir)
      local res = movement.move(g, p, case.steps, {
        branch_parity = case.steps,
        skip_market_check = true,
      })
      local landing_tile = assert(res.landing_tile, "fresh inner roll should land on a tile")
      _assert_eq(landing_tile.id, case.expected_tile_id,
        "fresh inner roll should keep saved direction from tile " .. tostring(case.start_tile_id))
    end
  end

  function TestMovement:test_resume_forward_from_inner_ring_keeps_explicit_direction(self)
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

  function TestMovement:test_resume_forward_requires_explicit_direction(self)
    local g = _new_game()
    local p = g:current_player()
    local ok, err = pcall(function()
      facing_policy.resolve_initial_facing("resume_forward", p, {})
    end)
    lu.assertEvalToTrue(ok == false, "resume_forward should reject missing opts.direction")
    lu.assertEvalToTrue(tostring(err):find("resume_forward requires opts.direction", 1, true) ~= nil,
      "resume_forward should report the missing direction contract")
  end

  function TestMovement:test_move_anim_play_sequence_emits_step_sound_per_visited_tile(self)
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
      lu.assertEvalToTrue(math.abs(total - 0.3) < 0.0001, "three steps should sum patched step duration")
      table.sort(scheduled, function(a, b)
        return a.delay < b.delay
      end)
      for _, entry in ipairs(scheduled) do
        entry.fn()
      end
    end)

    lu.assertEvalToTrue(#calls == 3, "move sequence should emit one step sound per visited tile")
    _assert_eq(calls[1].tile_index, 2, "step sound should target first visited tile")
    _assert_eq(calls[2].tile_index, 3, "step sound should target second visited tile")
    _assert_eq(calls[3].tile_index, 4, "step sound should target final visited tile")
    lu.assertEvalToTrue(#step_calls == 3, "move sequence should still execute three steps")
  end

  function TestMovement:test_default_map_reload_builds_bidirectional_neighbors(self)
    local original = package.loaded["src.config.content.default_map"]
    package.loaded["src.config.content.default_map"] = nil
    local reloaded = require("src.config.content.default_map")
    package.loaded["src.config.content.default_map"] = original or reloaded

    local start_neighbors = reloaded.neighbors[reloaded.start_id]
    lu.assertEvalToTrue(type(start_neighbors) == "table", "reloaded default map should expose neighbors for start tile")
    _assert_eq(start_neighbors.left ~= nil or start_neighbors.up ~= nil or start_neighbors.right ~= nil or start_neighbors.down ~= nil,
      true,
      "start tile should connect to at least one neighbor")

    local market_entry = reloaded.entry_points[reloaded.market_id]
    lu.assertEvalToTrue(market_entry == nil, "market tile itself should not be an outer entry point")

    local sample_outer_id = reloaded.path[1]
    local next_outer_id = reloaded.outer_next[sample_outer_id]
    local direction = reloaded.direction(sample_outer_id, next_outer_id)
    _assert_eq(reloaded.neighbors[sample_outer_id][direction], next_outer_id,
      "neighbor map should be bidirectional with direction lookup after reload")
  end
end


return TestMovement
