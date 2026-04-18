local roll = require("src.turn.phases.roll")

local _roll_dice_tests = {
  function()
    local results, total = roll._roll_dice(3, { 4, 5, 6 }, nil)
    assert(#results == 3, "should return 3 results")
    assert(results[1] == 4 and results[2] == 5 and results[3] == 6, "should use override values")
    assert(total == 15, "total should sum override values")
  end,
  function()
    local results = roll._roll_dice(4, { 2, 3 }, { next_int = function() return 6 end })
    assert(#results == 4, "should return 4 results")
    assert(results[1] == 2 and results[2] == 3, "should use provided overrides")
    assert(results[3] == 3 and results[4] == 3, "should repeat last override value")
  end,
  function()
    local results, total = roll._roll_dice(2, nil, { next_int = function() return 4 end })
    assert(#results == 2, "should return 2 results")
    assert(results[1] == 4 and results[2] == 4, "should use rng when no override")
    assert(total == 8, "total should sum rng values")
  end,
  function()
    local results, total = roll._roll_dice(1, {}, { next_int = function() return 3 end })
    assert(#results == 1, "should return 1 result")
    assert(results[1] == 3, "should use rng when override is empty table")
    assert(total == 3, "total should be rng value")
  end,
}

local _apply_dice_multiplier_tests = {
  function()
    local turn_mgr = {
      game = {
        board = { get_tile = function() return { type = "normal" } end },
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { { id = 1, position = 1, status = { pending_dice_multiplier = 3 } } },
        anim_gate_port = { wait_move_anim = false },
      },
    }
    local original_movement = require("src.rules.movement")
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function() return { visited = {}, steps = {} } end
    }
    package.loaded["src.turn.phases.move_followup"] = {
      run = function() return "test_result" end
    }
    package.loaded["src.turn.phases.move"] = nil
    local move_module = require("src.turn.phases.move")
    local result = move_module(turn_mgr, {
      player = turn_mgr.game.players[1],
      total = 4,
      raw_total = 4,
    })
    package.loaded["src.rules.movement"] = original_movement
    package.loaded["src.turn.phases.move_followup"] = original_move_followup
    package.loaded["src.turn.phases.move"] = nil
    assert(result == "test_result", "should complete move phase")
  end,
  function()
    local turn_mgr = {
      game = {
        board = { get_tile = function() return { type = "normal" } end },
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { { id = 1, position = 1, status = { pending_dice_multiplier = 1 } } },
        anim_gate_port = { wait_move_anim = false },
      },
    }
    local original_movement = package.loaded["src.rules.movement"]
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function() return { visited = {}, steps = {} } end
    }
    package.loaded["src.turn.phases.move_followup"] = {
      run = function() return "test_result" end
    }
    package.loaded["src.turn.phases.move"] = nil
    local move_module = require("src.turn.phases.move")
    local result = move_module(turn_mgr, {
      player = turn_mgr.game.players[1],
      total = 7,
      raw_total = 7,
    })
    package.loaded["src.rules.movement"] = original_movement
    package.loaded["src.turn.phases.move_followup"] = original_move_followup
    package.loaded["src.turn.phases.move"] = nil
    assert(result == "test_result", "should complete move phase with multiplier 1")
  end,
  function()
    local turn_mgr = {
      game = {
        board = { get_tile = function() return { type = "normal" } end },
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { { id = 1, position = 1, status = { pending_dice_multiplier = 2 } } },
        anim_gate_port = { wait_move_anim = false },
      },
    }
    local original_movement = package.loaded["src.rules.movement"]
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function() return { visited = {}, steps = {} } end
    }
    package.loaded["src.turn.phases.move_followup"] = {
      run = function() return "test_result" end
    }
    package.loaded["src.turn.phases.move"] = nil
    local move_module = require("src.turn.phases.move")
    local result = move_module(turn_mgr, {
      player = turn_mgr.game.players[1],
      total = 10,
      raw_total = 8,
    })
    package.loaded["src.rules.movement"] = original_movement
    package.loaded["src.turn.phases.move_followup"] = original_move_followup
    package.loaded["src.turn.phases.move"] = nil
    assert(result == "test_result", "should skip multiplier when total ~= raw_total")
  end,
  function()
    local turn_mgr = {
      game = {
        board = { get_tile = function() return { type = "normal" } end },
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { { id = 1, position = 1, status = {} } },
        anim_gate_port = { wait_move_anim = false },
      },
    }
    local original_movement = package.loaded["src.rules.movement"]
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function() return { visited = {}, steps = {} } end
    }
    package.loaded["src.turn.phases.move_followup"] = {
      run = function() return "test_result" end
    }
    package.loaded["src.turn.phases.move"] = nil
    local move_module = require("src.turn.phases.move")
    local result = move_module(turn_mgr, {
      player = turn_mgr.game.players[1],
      total = 5,
      raw_total = 5,
    })
    package.loaded["src.rules.movement"] = original_movement
    package.loaded["src.turn.phases.move_followup"] = original_move_followup
    package.loaded["src.turn.phases.move"] = nil
    assert(result == "test_result", "should complete move phase without multiplier")
  end,
  function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 4 } }
    local turn_mgr = {
      game = {
        board = { get_tile = function() return { type = "normal" } end },
        turn = { move_anim_seq = 0, last_turn = {} },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function(self, p, key, value)
          p.status[key] = value
        end,
      },
    }
    local original_movement = package.loaded["src.rules.movement"]
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function(game, p, total)
        assert(total == 12, "total should be multiplied: expected 12, got " .. tostring(total))
        return { visited = {}, steps = {} }
      end
    }
    package.loaded["src.turn.phases.move_followup"] = {
      run = function() return "test_result" end
    }
    package.loaded["src.turn.phases.move"] = nil
    local move_module = require("src.turn.phases.move")
    local result = move_module(turn_mgr, {
      player = player,
      total = 3,
      raw_total = 3,
    })
    assert(player.status.pending_dice_multiplier == 1, "should reset multiplier to 1")
    package.loaded["src.rules.movement"] = original_movement
    package.loaded["src.turn.phases.move_followup"] = original_move_followup
    package.loaded["src.turn.phases.move"] = nil
    assert(result == "test_result", "should complete move phase")
  end,
  function()
    local player = { id = 1, position = 1, status = { pending_dice_multiplier = 3 } }
    local turn_mgr = {
      game = {
        board = { get_tile = function() return { type = "normal" } end },
        turn = { move_anim_seq = 0 },
        dirty = {},
        players = { player },
        anim_gate_port = { wait_move_anim = false },
        set_player_status = function() end,
      },
    }
    local original_movement = package.loaded["src.rules.movement"]
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function(game, p, total)
        assert(total == 6, "total should not be multiplied when raw_total is nil")
        return { visited = {}, steps = {} }
      end
    }
    package.loaded["src.turn.phases.move_followup"] = {
      run = function() return "test_result" end
    }
    package.loaded["src.turn.phases.move"] = nil
    local move_module = require("src.turn.phases.move")
    local result = move_module(turn_mgr, {
      player = player,
      total = 6,
      raw_total = nil,
    })
    package.loaded["src.rules.movement"] = original_movement
    package.loaded["src.turn.phases.move_followup"] = original_move_followup
    package.loaded["src.turn.phases.move"] = nil
    assert(result == "test_result", "should skip multiplier when raw_total is nil")
  end,
}

local _roll_dice_extended_tests = {
  function()
    local results, total = roll._roll_dice(2, nil, { next_int = function() return 5 end })
    assert(#results == 2, "should return correct number of results")
    assert(results[1] == 5 and results[2] == 5, "should use rng for all dice")
    assert(total == 10, "total should be sum of rng values")
  end,
  function()
    local results, total = roll._roll_dice(3, { 6 }, { next_int = function() return 2 end })
    assert(#results == 3, "should return 3 results with single override")
    assert(results[1] == 6 and results[2] == 6 and results[3] == 6, "should repeat single override value")
    assert(total == 18, "total should be sum of repeated override values")
  end,
  function()
    -- Test with zero dice count
    local results, total = roll._roll_dice(0, nil, { next_int = function() return 3 end })
    assert(#results == 0, "should return empty results for zero dice")
    assert(total == 0, "total should be 0 for zero dice")
  end,
  function()
    -- Test with single die using rng
    local results, total = roll._roll_dice(1, nil, { next_int = function(_, min, max) return min end })
    assert(#results == 1, "should return 1 result")
    assert(results[1] == 1, "should use min value from rng")
    assert(total == 1, "total should be min value")
  end,
  function()
    -- Test with more override values than dice count
    local results, total = roll._roll_dice(2, { 1, 2, 3, 4 }, { next_int = function() return 6 end })
    assert(#results == 2, "should return only 2 results")
    assert(results[1] == 1 and results[2] == 2, "should use first 2 override values")
    assert(total == 3, "total should be sum of first 2 values")
  end,
  function()
    -- Test with exact match override values
    local results, total = roll._roll_dice(3, { 2, 4, 6 }, { next_int = function() return 1 end })
    assert(#results == 3, "should return 3 results")
    assert(results[1] == 2 and results[2] == 4 and results[3] == 6, "should use all override values")
    assert(total == 12, "total should be sum of all values")
  end,
}

return {
  name = "movement_dice",
  tests = {
    { name = "_test_roll_dice_with_override_uses_provided_values", run = _roll_dice_tests[1] },
    { name = "_test_roll_dice_with_partial_override_uses_last_for_remaining", run = _roll_dice_tests[2] },
    { name = "_test_roll_dice_with_rng_no_override", run = _roll_dice_tests[3] },
    { name = "_test_roll_dice_with_empty_override_uses_rng", run = _roll_dice_tests[4] },
    { name = "_test_apply_dice_multiplier_with_multiplier", run = _apply_dice_multiplier_tests[1] },
    { name = "_test_apply_dice_multiplier_multiplier_one", run = _apply_dice_multiplier_tests[2] },
    { name = "_test_apply_dice_multiplier_total_mismatch", run = _apply_dice_multiplier_tests[3] },
    { name = "_test_apply_dice_multiplier_no_multiplier", run = _apply_dice_multiplier_tests[4] },
    { name = "_test_apply_dice_multiplier_applies_and_resets", run = _apply_dice_multiplier_tests[5] },
    { name = "_test_apply_dice_multiplier_nil_raw_total", run = _apply_dice_multiplier_tests[6] },
    { name = "_test_roll_dice_with_rng", run = _roll_dice_extended_tests[1] },
    { name = "_test_roll_dice_single_override", run = _roll_dice_extended_tests[2] },
    { name = "_test_roll_dice_zero_count", run = _roll_dice_extended_tests[3] },
    { name = "_test_roll_dice_single_die_rng", run = _roll_dice_extended_tests[4] },
    { name = "_test_roll_dice_more_overrides", run = _roll_dice_extended_tests[5] },
    { name = "_test_roll_dice_exact_overrides", run = _roll_dice_extended_tests[6] },
  },
}
