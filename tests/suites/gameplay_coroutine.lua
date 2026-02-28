local support = require("TestSupport")
local runtime_constants = require("Config.RuntimeConstants")
local turn_engine = require("src.game.core.runtime.TurnEngine")

local function _with_coroutine_flag(enabled, fn)
  support.with_patches({
    { target = runtime_constants, key = "experimental_coroutine_turn", value = enabled == true },
  }, fn)
end

---------------------------------------------------------------------------
-- 1. legacy mode default
---------------------------------------------------------------------------
local function _test_turn_engine_defaults_to_legacy_mode()
  _with_coroutine_flag(false, function()
    local g = support.new_game()
    assert(g.turn_engine ~= nil, "game should have turn_engine")
    assert(g.turn_engine:is_coroutine_mode() == false, "default turn_engine mode should be legacy")
  end)
end

---------------------------------------------------------------------------
-- 2. wait_choice (existing)
---------------------------------------------------------------------------
local function _test_turn_engine_coroutine_mode_resolves_wait_choice()
  _with_coroutine_flag(true, function()
    local g = support.new_game()
    g.turn_engine = turn_engine:new(g, {
      start = function()
        return "wait_choice", { resume_state = "done", resume_args = {} }
      end,
      done = function()
        return nil
      end,
    }, {
      experimental_coroutine_turn = true,
    })

    local choice = support.open_choice(g, {
      kind = "item_phase_choice",
      title = "行动前：使用道具？",
      options = { { id = 2001, label = "路障卡" } },
      allow_cancel = true,
      cancel_label = "结束阶段",
      meta = {
        phase = "pre_action",
        player_id = g:current_player().id,
      },
    })

    g:advance_turn()
    assert(g.turn.phase == "wait_choice", "coroutine turn_engine should enter wait_choice")

    g:dispatch_action({
      type = "choice_cancel",
      choice_id = choice.id,
      actor_role_id = g:current_player().id,
    })

    assert(g.turn.pending_choice == nil, "choice_cancel should clear pending choice in coroutine mode")
    assert(g.turn.phase ~= "wait_choice", "coroutine mode should leave wait_choice after cancel")
  end)
end

---------------------------------------------------------------------------
-- 3. wait_move_anim
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_wait_move_anim()
  _with_coroutine_flag(true, function()
    local g = support.new_game()
    local move_seq = 42

    g.turn_engine = turn_engine:new(g, {
      start = function()
        g.turn.move_anim = { seq = move_seq, player_id = g:current_player().id }
        return "wait_move_anim", { resume_state = "done", resume_args = {} }
      end,
      done = function()
        return nil
      end,
    }, {
      experimental_coroutine_turn = true,
    })

    g:advance_turn()
    assert(g.turn.phase == "wait_move_anim", "should enter wait_move_anim")

    -- wrong seq -> should stay waiting
    g:dispatch_action({ type = "move_anim_done", seq = 999 })
    assert(g.turn.phase == "wait_move_anim", "wrong seq should keep waiting")

    -- correct seq -> should advance
    g:dispatch_action({ type = "move_anim_done", seq = move_seq })
    assert(g.turn.phase ~= "wait_move_anim", "correct seq should leave wait_move_anim")
  end)
end

---------------------------------------------------------------------------
-- 4. wait_action_anim
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_wait_action_anim()
  _with_coroutine_flag(true, function()
    local g = support.new_game()
    local anim_seq = 99

    g.turn_engine = turn_engine:new(g, {
      start = function()
        g.turn.action_anim = { seq = anim_seq, kind = "roll", player_id = g:current_player().id }
        return "wait_action_anim", { resume_state = "done", resume_args = {} }
      end,
      done = function()
        return nil
      end,
    }, {
      experimental_coroutine_turn = true,
    })

    g:advance_turn()
    assert(g.turn.phase == "wait_action_anim", "should enter wait_action_anim")

    -- wrong seq -> should stay waiting
    g:dispatch_action({ type = "action_anim_done", seq = 1 })
    assert(g.turn.phase == "wait_action_anim", "wrong seq should keep waiting")

    -- correct seq -> should advance
    g:dispatch_action({ type = "action_anim_done", seq = anim_seq })
    assert(g.turn.phase ~= "wait_action_anim", "correct seq should leave wait_action_anim")
  end)
end

---------------------------------------------------------------------------
-- 5. detained_wait
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_detained_wait()
  _with_coroutine_flag(true, function()
    local g = support.new_game()

    g.turn_engine = turn_engine:new(g, {
      start = function()
        g.turn.detained_wait_active = true
        return "detained_wait", {}
      end,
      end_turn = function()
        return nil
      end,
    }, {
      experimental_coroutine_turn = true,
    })

    g:advance_turn()
    assert(g.turn.phase == "detained_wait", "should enter detained_wait")

    -- still active -> should stay waiting
    g:advance_turn()
    assert(g.turn.phase == "detained_wait", "should stay in detained_wait while active")

    -- clear detained -> should proceed to end_turn and finish
    g.turn.detained_wait_active = false
    g:advance_turn()
    assert(g.turn.phase ~= "detained_wait", "should leave detained_wait when cleared")
  end)
end

---------------------------------------------------------------------------
-- 6. full turn lifecycle (start -> roll -> move -> landing -> post -> end)
---------------------------------------------------------------------------
local function _test_coroutine_mode_full_turn_lifecycle()
  _with_coroutine_flag(true, function()
    local g = support.new_game()
    local visited = {}

    g.turn_engine = turn_engine:new(g, {
      start = function(_, args)
        visited[#visited + 1] = "start"
        return "roll", { player = g:current_player() }
      end,
      roll = function(_, args)
        visited[#visited + 1] = "roll"
        return "move", args
      end,
      move = function(_, args)
        visited[#visited + 1] = "move"
        return "landing", args
      end,
      landing = function(_, args)
        visited[#visited + 1] = "landing"
        return "post_action", args
      end,
      post_action = function(_, args)
        visited[#visited + 1] = "post_action"
        return "end_turn", args
      end,
      end_turn = function()
        visited[#visited + 1] = "end_turn"
        return nil
      end,
    }, {
      experimental_coroutine_turn = true,
    })

    g:advance_turn()

    local expected = { "start", "roll", "move", "landing", "post_action", "end_turn" }
    assert(#visited == #expected,
      "should visit all " .. #expected .. " phases, got " .. #visited)
    for i, name in ipairs(expected) do
      assert(visited[i] == name,
        "phase " .. i .. " should be " .. name .. " got " .. tostring(visited[i]))
    end
  end)
end

---------------------------------------------------------------------------
-- 7. coroutine and legacy produce same result
---------------------------------------------------------------------------
local function _test_coroutine_and_legacy_produce_same_result()
  local function make_phases()
    local counter = { value = 0 }
    local phases = {
      start = function()
        counter.value = counter.value + 1
        return "wait_choice", { resume_state = "done", resume_args = {} }
      end,
      done = function()
        counter.value = counter.value + 10
        return nil
      end,
    }
    return phases, counter
  end

  -- Run in legacy mode
  local legacy_pending, legacy_counter
  _with_coroutine_flag(false, function()
    local g = support.new_game()
    local phases, counter = make_phases()
    g.turn_engine = turn_engine:new(g, phases, { experimental_coroutine_turn = false })
    g.turn_flow = nil -- avoid _resolve_turn_runtime falling back to old turn_flow

    local choice = support.open_choice(g, {
      kind = "test_choice",
      title = "test",
      options = { { id = 1, label = "opt1" } },
      allow_cancel = true,
    })

    g:advance_turn()
    g:dispatch_action({
      type = "choice_cancel",
      choice_id = choice.id,
      actor_role_id = g:current_player().id,
    })

    legacy_pending = g.turn.pending_choice
    legacy_counter = counter.value
  end)

  -- Run in coroutine mode
  local coro_pending, coro_counter
  _with_coroutine_flag(true, function()
    local g = support.new_game()
    local phases, counter = make_phases()
    g.turn_engine = turn_engine:new(g, phases, { experimental_coroutine_turn = true })

    local choice = support.open_choice(g, {
      kind = "test_choice",
      title = "test",
      options = { { id = 1, label = "opt1" } },
      allow_cancel = true,
    })

    g:advance_turn()
    g:dispatch_action({
      type = "choice_cancel",
      choice_id = choice.id,
      actor_role_id = g:current_player().id,
    })

    coro_pending = g.turn.pending_choice
    coro_counter = counter.value
  end)

  -- Compare results
  assert(legacy_pending == coro_pending,
    "pending_choice mismatch: legacy=" .. tostring(legacy_pending)
    .. " coroutine=" .. tostring(coro_pending))
  assert(legacy_counter == coro_counter,
    "counter mismatch: legacy=" .. tostring(legacy_counter)
    .. " coroutine=" .. tostring(coro_counter))
end

---------------------------------------------------------------------------
-- suite export
---------------------------------------------------------------------------
return {
  name = "gameplay.coroutine",
  tests = {
    {
      name = "turn_engine_defaults_to_legacy_mode",
      run = _test_turn_engine_defaults_to_legacy_mode,
    },
    {
      name = "turn_engine_coroutine_mode_resolves_wait_choice",
      run = _test_turn_engine_coroutine_mode_resolves_wait_choice,
    },
    {
      name = "coroutine_mode_resolves_wait_move_anim",
      run = _test_coroutine_mode_resolves_wait_move_anim,
    },
    {
      name = "coroutine_mode_resolves_wait_action_anim",
      run = _test_coroutine_mode_resolves_wait_action_anim,
    },
    {
      name = "coroutine_mode_resolves_detained_wait",
      run = _test_coroutine_mode_resolves_detained_wait,
    },
    {
      name = "coroutine_mode_full_turn_lifecycle",
      run = _test_coroutine_mode_full_turn_lifecycle,
    },
    {
      name = "coroutine_and_legacy_produce_same_result",
      run = _test_coroutine_and_legacy_produce_same_result,
    },
  },
}
