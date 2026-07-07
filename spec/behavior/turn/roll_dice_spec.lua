local roll = require("src.turn.phases.roll")
local dice_multiplier = require("src.turn.phases.dice_multiplier")
local status_ops = require("src.player.actions.status")

local function _test_apply_roll_total_uses_pending_multiplier()
  local game = { player_pending_dice_multiplier = status_ops.player_pending_dice_multiplier }
  local boosted = { id = 1, status = { pending_dice_multiplier = 4 } }
  assert(dice_multiplier.apply_roll_total(game, 3, boosted) == 12,
    "apply_roll_total should multiply raw total by the pending multiplier")
  local plain = { id = 2, status = {} }
  assert(dice_multiplier.apply_roll_total(game, 5, plain) == 5,
    "apply_roll_total should pass through raw total without a multiplier")
end

local _apply_dice_multiplier_tests = {
  function()
    local player = { id = 1, name = "P1", position = 1, status = { pending_dice_multiplier = 4 } }
    local game = {
      board = { get_tile = function() return { type = "normal" } end },
      turn = { move_anim_seq = 0, last_turn = {} },
      dirty = {},
      players = { player },
      anim_gate_port = { wait_move_anim = false },
      player_pending_dice_multiplier = status_ops.player_pending_dice_multiplier,
      consume_pending_dice_multiplier = status_ops.consume_pending_dice_multiplier,
    }
    local turn_mgr = { game = game }
    local original_movement = package.loaded["src.rules.movement"]
    local original_move_followup = package.loaded["src.turn.phases.move_followup"]
    package.loaded["src.rules.movement"] = {
      move = function(_, _, total)
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
    assert(game:player_pending_dice_multiplier(player) == 1, "should reset multiplier to 1")
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
        player_pending_dice_multiplier = status_ops.player_pending_dice_multiplier,
        consume_pending_dice_multiplier = status_ops.consume_pending_dice_multiplier,
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
    local results, total = roll._roll_dice(0, nil, { next_int = function() return 3 end })
    assert(#results == 0, "should return empty results for zero dice")
    assert(total == 0, "total should be 0 for zero dice")
  end,
  function()
    local results, total = roll._roll_dice(1, nil, { next_int = function(_, min, max) return min end })
    assert(#results == 1, "should return 1 result")
    assert(results[1] == 1, "should use min value from rng")
    assert(total == 1, "total should be min value")
  end,
  function()
    local results, total = roll._roll_dice(2, { 1, 2, 3, 4 }, { next_int = function() return 6 end })
    assert(#results == 2, "should return only 2 results")
    assert(results[1] == 1 and results[2] == 2, "should use first 2 override values")
    assert(total == 3, "total should be sum of first 2 values")
  end,
}

describe("movement_dice", function()
  it("_test_apply_roll_total_uses_pending_multiplier", _test_apply_roll_total_uses_pending_multiplier)

  it("_test_apply_dice_multiplier_applies_and_resets", _apply_dice_multiplier_tests[1])

  it("_test_apply_dice_multiplier_nil_raw_total", _apply_dice_multiplier_tests[2])

  it("_test_roll_dice_zero_count", _roll_dice_extended_tests[1])

  it("_test_roll_dice_single_die_rng", _roll_dice_extended_tests[2])

  it("_test_roll_dice_more_overrides", _roll_dice_extended_tests[3])
end)
