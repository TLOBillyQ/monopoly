local roll = require("src.turn.phases.roll")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- _roll_dice






-- _resolve_phase_wait_result





-- _phase_roll_with_pre_move / _phase_roll (anim gate paths)

local function _make_game(wait_action_anim)
  local anim_queued = {}
  local game = {
    anim_gate_port = { wait_action_anim = wait_action_anim },
    queue_action_anim = function(_, payload) anim_queued[#anim_queued + 1] = payload end,
    player_dice_count = function(_, _) return 2 end,
    rng = { next_int = function(_, _, _) return 3 end },
    last_turn = {},
  }
  return game, anim_queued
end

describe("domain roll coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("roll_dice override values exact count", function()
    local results, total = roll._roll_dice(3, { 2, 4, 6 }, nil)
    _assert_eq(#results, 3, "should return 3 results")
    _assert_eq(total, 12, "total should be 2+4+6=12")
    _assert_eq(results[1], 2, "first result should be 2")
    _assert_eq(results[2], 4, "second result should be 4")
    _assert_eq(results[3], 6, "third result should be 6")
  end)

  it("roll_dice override values fewer than count uses last", function()
    local results, total = roll._roll_dice(3, { 3, 5 }, nil)
    _assert_eq(#results, 3, "should return 3 results")
    _assert_eq(results[3], 5, "third result should use last override value")
    _assert_eq(total, 3 + 5 + 5, "total should be 13")
  end)

  it("roll_dice override single value repeats", function()
    local results, total = roll._roll_dice(2, { 4 }, nil)
    _assert_eq(#results, 2, "should return 2 results")
    _assert_eq(results[1], 4, "first result should be 4")
    _assert_eq(results[2], 4, "second result should repeat 4")
    _assert_eq(total, 8, "total should be 8")
  end)

  it("roll_dice with rng", function()
    local call_count = 0
    local rng = {
      next_int = function(_, _, _)
        call_count = call_count + 1
        return call_count
      end,
    }
    local results, total = roll._roll_dice(3, nil, rng)
    _assert_eq(#results, 3, "should return 3 results")
    _assert_eq(total, 6, "total should be 1+2+3=6")
    _assert_eq(call_count, 3, "rng should be called 3 times")
  end)

  it("roll_dice empty override uses rng", function()
    local rng = {
      next_int = function() return 5 end,
    }
    local results, total = roll._roll_dice(2, {}, rng)
    _assert_eq(#results, 2, "should return 2 results from rng")
    _assert_eq(total, 10, "total should be 5+5=10")
  end)

  it("resolve_phase_wait_result nil phase_res defaults", function()
    local player = { id = 1 }
    local state, args = roll._resolve_phase_wait_result(nil, player, 5, 5)
    _assert_eq(state, "wait_choice", "nil phase_res should default to wait_choice")
    _assert_eq(args.next_state, "move", "nil phase_res should default next_state to move")
    _assert_eq(args.next_args.player, player, "next_args should include player")
    _assert_eq(args.next_args.total, 5, "next_args should include total")
  end)

  it("resolve_phase_wait_result wait_action_anim=true", function()
    local player = { id = 2 }
    local phase_res = { wait_action_anim = true, next_state = "pre_move" }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 3, 3)
    _assert_eq(state, "wait_action_anim", "wait_action_anim=true should return wait_action_anim state")
    _assert_eq(args.next_state, "pre_move", "next_state should be from phase_res")
  end)

  it("resolve_phase_wait_result with custom next_args", function()
    local player = { id = 3 }
    local custom_args = { mode = "special" }
    local phase_res = { next_state = "custom", next_args = custom_args, wait_action_anim = false }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 4, 4)
    _assert_eq(state, "wait_choice", "wait_action_anim=false should return wait_choice")
    _assert_eq(args.next_args, custom_args, "should use phase_res.next_args when provided")
  end)

  it("resolve_phase_wait_result nil next_args builds default", function()
    local player = { id = 4 }
    local phase_res = { next_state = "special", next_args = nil }
    local state, args = roll._resolve_phase_wait_result(phase_res, player, 7, 6)
    _assert_eq(state, "wait_choice", "should return wait_choice")
    _assert_eq(args.next_state, "special", "next_state from phase_res")
    _assert_eq(args.next_args.total, 7, "total should be in default next_args")
    _assert_eq(args.next_args.raw_total, 6, "raw_total should be in default next_args")
  end)

  it("phase_roll_with_pre_move queues anim and returns wait", function()
    local game, anim_queued = _make_game(true)
    local player = { id = 1, name = "P1", status = {} }
    local turn_mgr = { game = game }
    local state, args = roll._phase_roll_with_pre_move(turn_mgr, { player = player, skip_anim = false })
    _assert_eq(state, "wait_action_anim", "anim gate active should return wait_action_anim")
    _assert_eq(args.next_state, "roll", "next_state should be roll for retry after anim")
    _assert_eq(args.next_args.skip_anim, true, "retry args should have skip_anim=true")
    _assert_eq(#anim_queued, 1, "should queue one roll animation")
    _assert_eq(anim_queued[1].kind, "roll", "animation kind should be roll")
    assert(anim_queued[1].player_id == player.id, "animation player_id should match")
  end)

  it("phase_roll_with_pre_move no anim gate returns pre_move", function()
    local game, _ = _make_game(false)
    local player = { id = 2, name = "P2", status = {} }
    local turn_mgr = { game = game }
    local state, args = roll._phase_roll_with_pre_move(turn_mgr, { player = player })
    _assert_eq(state, "pre_move", "no anim gate should return pre_move")
    _assert_eq(args.player, player, "args should include player")
  end)

  it("phase_roll_with_pre_move skip_anim bypasses gate", function()
    local game, anim_queued = _make_game(true)
    local player = { id = 3, name = "P3", status = {} }
    local turn_mgr = { game = game }
    local state, _ = roll._phase_roll_with_pre_move(turn_mgr, { player = player, skip_anim = true })
    _assert_eq(state, "pre_move", "skip_anim=true should bypass anim gate and return pre_move")
    _assert_eq(#anim_queued, 0, "should not queue animation when skip_anim=true")
  end)

  it("phase_roll_direct passes through anim state", function()
    local game, anim_queued = _make_game(true)
    local player = { id = 4, name = "P4", status = {} }
    local turn_mgr = { game = game }
    local state, args = roll._phase_roll(turn_mgr, { player = player })
    _assert_eq(state, "wait_action_anim", "phase_roll direct should pass through wait_action_anim")
    _assert_eq(args.next_state, "roll", "should retain next_state from inner result")
    _assert_eq(#anim_queued, 1, "should queue animation via direct roll")
  end)

  it("phase_roll_direct maps pre_move to move", function()
    local game, _ = _make_game(false)
    local player = { id = 5, name = "P5", status = {} }
    local turn_mgr = { game = game }
    local state, args = roll._phase_roll(turn_mgr, { player = player })
    _assert_eq(state, "move", "pre_move should be mapped to move by phase_roll direct")
    _assert_eq(args.player, player, "move args should include player")
  end)
end)
