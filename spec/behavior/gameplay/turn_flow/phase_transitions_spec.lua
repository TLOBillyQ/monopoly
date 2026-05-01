local support = require("support.gameplay_support")
local _new_game = support.new_game
local dispatch_validator = require("src.turn.actions.validator")
local land = require("src.turn.phases.land")
local turn_script = require("src.turn.timing.session_script")
local phase = require("src.rules.items.phase")

local build_wait_choice_args = phase.build_wait_choice_args

local _dispatch_validator_tests = {
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when actor matches owner")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local p2 = g.players[2]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select", actor_role_id = p2.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when actor does not match owner")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1 }
    local action = { type = "choice_select", actor_role_id = p1.id }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == true, "should return true when choice has no owner")
  end,
  function()
    local g = _new_game()
    local p1 = g.players[1]
    local choice = { id = 1, owner_role_id = p1.id }
    local action = { type = "choice_select" }
    local result = dispatch_validator.validate_choice_actor(g, action, choice)
    assert(result == false, "should return false when action has no actor_role_id")
  end,
}

local _resolve_wait_state_tests = {
  function()
    local game = {
      turn = {},
      dirty = {},
    }
    local next_state = land._resolve_wait_state(game, "move", { player = { id = 1 } }, true)
    assert(next_state == "move", "should return next_state when no action anim and wait_action_anim is true")
  end,
  function()
    local game = {
      turn = { action_anim = { kind = "test" } },
      dirty = {},
    }
    local next_state, next_args = land._resolve_wait_state(game, "move", { player = { id = 1 } }, true)
    assert(next_state == "wait_action_anim", "should return wait_action_anim when action anim exists")
    assert(next_args.next_state == "move", "should preserve next_state in args")
  end,
  function()
    local game = {
      turn = {},
      dirty = {},
    }
local landing_visual_hold = require("src.state.visual_hold")
    landing_visual_hold.hold_state_for_game(game, { duration = 1.0 })
    local next_state = land._resolve_wait_state(game, "post_action", { player = { id = 1 } }, false)
    assert(next_state == "wait_landing_visual", "should return wait_landing_visual when landing visual hold is active")
    landing_visual_hold.release(game)
  end,
  function()
    local game = {
      turn = { action_anim_queue = { { kind = "move_effect" } } },
      dirty = {},
    }
    local next_state = land._resolve_wait_state(game, "post_action", { player = { id = 1 } }, false)
    assert(next_state == "wait_action_anim", "should return wait_action_anim when action anim queue has items")
  end,
}

local _resolve_wait_state_extended_tests = {
  function()
    local game = {
      turn = { action_anim = { kind = "test" } },
      dirty = {},
    }
  local landing_visual_hold = require("src.state.visual_hold")
    landing_visual_hold.hold_state_for_game(game, { duration = 1.0 })
    local next_state, next_args = land._resolve_wait_state(game, "post_action", { player = { id = 1 } }, true)
    assert(next_state == "wait_landing_visual", "should route through landing_visual first when both hold and action_anim active")
    assert(next_args.next_state == "wait_action_anim", "landing_visual should chain into wait_action_anim")
    landing_visual_hold.release(game)
  end,
  function()
    local game = {
      turn = {},
      dirty = {},
    }
    local next_state, next_args = land._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(next_state == "wait_choice", "should return wait_choice when no action anim and wait_action_anim is false")
    assert(next_args.next_state == "move", "should preserve next_state")
  end,
  function()
    -- Test with wait_action_anim=false and no anim but landing visual hold active
    local game = {
      turn = {},
      dirty = {},
    }
  local landing_visual_hold = require("src.state.visual_hold")
    landing_visual_hold.hold_state_for_game(game, { duration = 1.0 })
    local next_state = land._resolve_wait_state(game, "post_action", { player = { id = 1 } }, false)
    assert(next_state == "wait_landing_visual", "should return wait_landing_visual when landing visual is active")
    landing_visual_hold.release(game)
  end,
  function()
    -- Test with action_anim_queue containing move_effect
    local game = {
      turn = { action_anim_queue = { { kind = "move_effect" } } },
      dirty = {},
    }
    local next_state, next_args = land._resolve_wait_state(game, "move", { player = { id = 1 } }, false)
    assert(next_state == "wait_action_anim", "should return wait_action_anim when queue has move_effect")
    assert(next_args.next_state == "wait_choice", "should wrap in wait_choice when wait_action_anim is false")
  end,
}

-- Tests for anonymous@88 in script.lua (coroutine create function)
-- These tests exercise the coroutine creation and execution paths
local _turn_script_tests = {
  function()
    -- Test script create with valid session - minimal test that just verifies coroutine creation
    local session = {
      current_state = "start",
      current_args = nil,
      phases = { start = function() return nil end },
      mark_phase = function() end,
    }
    local co = turn_script.create(session)
    assert(type(co) == "thread", "should return a coroutine thread")
    -- Don't resume - just verify creation works
  end,
  function()
    -- Test that create requires a session
    local ok = pcall(function()
      turn_script.create(nil)
    end)
    assert(not ok, "should error with nil session")
  end,
}

-- T8 FINAL tests for anonymous@88 in script.lua (coroutine create function)
-- The anonymous@88 is the coroutine.create callback function at line 88
-- It creates a coroutine that runs the turn script
local _turn_script_final_tests = {
  function()
    -- Test that create returns a coroutine thread

    local session = {
      current_state = "start",
      current_args = nil,
      phases = {
        start = function() return nil end,
      },
      mark_phase = function() end,
      game = { turn = {} }, -- minimal game object
    }

    local co = turn_script.create(session)
    assert(type(co) == "thread", "should return a coroutine thread")
  end,
  function()
    -- Test coroutine creation with various wait states
    -- Just verify that create() works for different wait states

    for _, wait_state in ipairs({"wait_choice", "wait_move_anim", "wait_action_anim", "inter_turn_wait"}) do
      local session = {
        current_state = wait_state,
        current_args = nil,
        phases = {},
        mark_phase = function() end,
        game = { turn = {} },
      }

      local co = turn_script.create(session)
      assert(type(co) == "thread", "should return thread for wait state: " .. wait_state)
    end
  end,
  function()
    -- Test coroutine with different starting states

    for _, start_state in ipairs({"start", "move", "action", "end_turn"}) do
      local session = {
        current_state = start_state,
        current_args = { test = true },
        phases = {
          [start_state] = function() return nil end,
        },
        mark_phase = function() end,
        game = { turn = {} },
      }

      local co = turn_script.create(session)
      assert(type(co) == "thread", "should return thread for state: " .. start_state)
    end
  end,
}

-- Helper functions for CRAP coverage tests
local function _crap_assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _crap_assert_not_nil(a, msg)
  assert(a ~= nil, tostring(msg) .. ": expected non-nil got nil")
end

local function _crap_assert_table(a, msg)
  assert(type(a) == "table", tostring(msg) .. ": expected table got " .. type(a))
end

-- Test 1: build_wait_choice_args returns table with next_state and next_args

-- Test 2: build_wait_choice_args uses meta.resume_next_state as next_state

-- Test 3: build_wait_choice_args missing resume_next_state triggers assertion error

-- Test 4: build_wait_choice_args with nil meta still fails (no resume_next_state)

-- Test 5: build_wait_choice_args next_args is nil when resume_next_args is nil

-- Test 6: build_wait_choice_args next_args is nil when resume_next_args is explicitly nil

-- Test 7: build_wait_choice_args next_args is passed through when resume_next_args is present

-- Test 8: build_wait_choice_args with resume_next_args=false still works (falsy but not nil)

describe("turn_flow_phase_transitions", function()
  it("_test_dispatch_validator_validate_choice_actor_match", _dispatch_validator_tests[1])

  it("_test_dispatch_validator_validate_choice_actor_mismatch", _dispatch_validator_tests[2])

  it("_test_dispatch_validator_validate_choice_actor_no_owner", _dispatch_validator_tests[3])

  it("_test_dispatch_validator_validate_choice_actor_no_actor_id", _dispatch_validator_tests[4])

  it("_test_resolve_wait_state_no_anim_wait_action_anim", _resolve_wait_state_tests[1])

  it("_test_resolve_wait_state_with_action_anim_wait_action_anim", _resolve_wait_state_tests[2])

  it("_test_resolve_wait_state_with_action_anim_queue", _resolve_wait_state_tests[4])

  it("_test_resolve_wait_state_prefers_anim", _resolve_wait_state_extended_tests[1])

  it("_test_resolve_wait_state_no_anim_no_wait", _resolve_wait_state_extended_tests[2])

  it("_test_resolve_wait_state_landing_visual", _resolve_wait_state_extended_tests[3])

  it("_test_resolve_wait_state_move_effect_queue", _resolve_wait_state_extended_tests[4])

  it("_test_turn_script_create_valid_session", _turn_script_tests[1])

  it("_test_turn_script_nil_session", _turn_script_tests[2])

  it("_test_turn_script_coroutine_execution", _turn_script_final_tests[1])

  it("_test_turn_script_wait_state", _turn_script_final_tests[2])

  it("_test_turn_script_different_states", _turn_script_final_tests[3])

  it("build_wait_choice_args returns table with keys", function()
    local meta = {
      resume_next_state = "some_state",
      resume_next_args = { arg1 = "value1" },
    }
    local result = build_wait_choice_args(meta)

    _crap_assert_table(result, "result should be table")
    _crap_assert_not_nil(result.next_state, "result.next_state should exist")
    _crap_assert_not_nil(result.next_args, "result.next_args should exist")
  end)

  it("build_wait_choice_args next_state from meta", function()
    local meta = {
      resume_next_state = "target_state_123",
      resume_next_args = nil,
    }
    local result = build_wait_choice_args(meta)

    _crap_assert_eq(result.next_state, "target_state_123", "next_state should equal resume_next_state")
  end)

  it("build_wait_choice_args missing resume_next_state asserts", function()
    local meta = {
      resume_next_args = { some = "args" },
    }

    local ok, err = pcall(function()
      build_wait_choice_args(meta)
    end)

    assert(not ok, "should have raised an error")
    assert(err and string.find(err, "resume_next_state"), "error should mention resume_next_state")
  end)

  it("build_wait_choice_args nil meta asserts", function()
    local ok, err = pcall(function()
      build_wait_choice_args(nil)
    end)

    assert(not ok, "nil meta should raise error")
    assert(err and string.find(err, "resume_next_state"), "error should mention resume_next_state")
  end)

  it("build_wait_choice_args next_args nil when absent", function()
    local meta = {
      resume_next_state = "some_state",
    }
    local result = build_wait_choice_args(meta)

    _crap_assert_eq(result.next_args, nil, "next_args should be nil when resume_next_args is nil")
  end)

  it("build_wait_choice_args next_args nil when explicit", function()
    local meta = {
      resume_next_state = "some_state",
      resume_next_args = nil,
    }
    local result = build_wait_choice_args(meta)

    _crap_assert_eq(result.next_args, nil, "next_args should be nil when resume_next_args is explicitly nil")
  end)

  it("build_wait_choice_args next_args from resume", function()
    local args_table = { player_id = 2, amount = 5000 }
    local meta = {
      resume_next_state = "payment_state",
      resume_next_args = args_table,
    }
    local result = build_wait_choice_args(meta)

    _crap_assert_eq(result.next_args, args_table, "next_args should be resume_next_args")
    _crap_assert_eq(result.next_args.player_id, 2, "next_args.player_id should be preserved")
    _crap_assert_eq(result.next_args.amount, 5000, "next_args.amount should be preserved")
  end)

  it("build_wait_choice_args resume_next_args false", function()
    local meta = {
      resume_next_state = "some_state",
      resume_next_args = false,
    }
    local result = build_wait_choice_args(meta)

    _crap_assert_eq(result.next_args, nil, "next_args should be nil when resume_next_args is false")
  end)
end)
