local support = require("support.gameplay_support")
local turn_engine = require("src.game.flow.turn.engine")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")
local await = require("src.game.flow.turn.await")

---------------------------------------------------------------------------
-- 1. coroutine mode default
---------------------------------------------------------------------------
local function _test_turn_engine_defaults_to_coroutine_mode()
  local g = support.new_game()
  assert(g.turn_engine ~= nil, "game should have turn_engine")
  assert(g.turn_engine:is_coroutine_mode() == true, "turn_engine mode should always be coroutine")
end

---------------------------------------------------------------------------
-- 2. wait_choice (existing)
---------------------------------------------------------------------------
local function _test_turn_engine_coroutine_mode_resolves_wait_choice()
  local g = support.new_game()
  g.turn_engine = turn_engine:new(g, {
    start = function()
      return "wait_choice", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  local choice = support.open_choice(g, {
    kind = "item_phase_choice",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
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
end

---------------------------------------------------------------------------
-- 3. wait_move_anim
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_wait_move_anim()
  local g = support.new_game()
  local move_seq = 42

  g.turn_engine = turn_engine:new(g, {
    start = function()
      g.turn.move_anim = { seq = move_seq, player_id = g:current_player().id }
      return "wait_move_anim", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  assert(g.turn.phase == "wait_move_anim", "should enter wait_move_anim")

  -- wrong seq -> should stay waiting
  g:dispatch_action({ type = "move_anim_done", seq = 999 })
  assert(g.turn.phase == "wait_move_anim", "wrong seq should keep waiting")

  -- correct seq -> should advance
  g:dispatch_action({ type = "move_anim_done", seq = move_seq })
  assert(g.turn.phase ~= "wait_move_anim", "correct seq should leave wait_move_anim")
end

---------------------------------------------------------------------------
-- 4. wait_action_anim
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_wait_action_anim()
  local g = support.new_game()
  local anim_seq = 99

  g.turn_engine = turn_engine:new(g, {
    start = function()
      g.turn.action_anim = { seq = anim_seq, kind = "roll", player_id = g:current_player().id }
      return "wait_action_anim", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  assert(g.turn.phase == "wait_action_anim", "should enter wait_action_anim")

  -- wrong seq -> should stay waiting
  g:dispatch_action({ type = "action_anim_done", seq = 1 })
  assert(g.turn.phase == "wait_action_anim", "wrong seq should keep waiting")

  -- correct seq -> should advance
  g:dispatch_action({ type = "action_anim_done", seq = anim_seq })
  assert(g.turn.phase ~= "wait_action_anim", "correct seq should leave wait_action_anim")
end

---------------------------------------------------------------------------
-- 5. detained_wait
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_detained_wait()
  local g = support.new_game()

  g.turn_engine = turn_engine:new(g, {
    start = function()
      g.turn.detained_wait_active = true
      return "detained_wait", {}
    end,
    end_turn = function()
      return nil
    end,
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
end

---------------------------------------------------------------------------
-- 6. wait_landing_visual
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_inter_turn_wait()
  local g = support.new_game()

  g.turn_engine = turn_engine:new(g, {
    start = function(_, args)
      if args and args.resumed == true then
        return "done", {}
      end
      g.turn.inter_turn_wait_active = true
      return "inter_turn_wait", { resumed = true }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  assert(g.turn.phase == "inter_turn_wait", "should enter inter_turn_wait")

  g:advance_turn()
  assert(g.turn.phase == "inter_turn_wait", "should stay in inter_turn_wait while active")

  g.turn.inter_turn_wait_active = false
  g:advance_turn()
  assert(g.turn.current_player_index == 2, "inter_turn_wait should advance to next player before restart")
  assert(g.turn.phase ~= "inter_turn_wait", "should leave inter_turn_wait when cleared")
end

---------------------------------------------------------------------------
-- 7. wait_landing_visual
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_wait_landing_visual()
  local g = support.new_game()
  landing_visual_hold.start(g)

  g.turn_engine = turn_engine:new(g, {
    start = function()
      return "wait_landing_visual", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  assert(g.turn.phase == "wait_landing_visual", "should enter wait_landing_visual")
  assert(g.turn.landing_visual_wait_ready == true, "wait_landing_visual should arm release callback")

  g:advance_turn()
  assert(g.turn.phase ~= "wait_landing_visual", "second advance should leave wait_landing_visual")
  assert(g.turn.landing_visual_release_pending == true, "wait_landing_visual should mark release pending")
end

---------------------------------------------------------------------------
-- 8. full turn lifecycle (start -> roll -> move -> landing -> post -> end)
---------------------------------------------------------------------------
local function _test_coroutine_mode_full_turn_lifecycle()
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
  })

  g:advance_turn()

  local expected = { "start", "roll", "move", "landing", "post_action", "end_turn" }
  assert(#visited == #expected,
    "should visit all " .. #expected .. " phases, got " .. #visited)
  for i, name in ipairs(expected) do
    assert(visited[i] == name,
      "phase " .. i .. " should be " .. name .. " got " .. tostring(visited[i]))
  end
end

local function _new_await_session(game, action)
  local session = {
    game = game,
    _action = action,
    _seconds_wait = {},
    marked_phase = nil,
  }
  function session:mark_phase(name)
    self.marked_phase = name
  end
  function session:take_pending_action()
    local next_action = self._action
    self._action = nil
    return next_action
  end
  function session:peek_pending_action()
    return self._action
  end
  function session:clear_pending_action()
    self._action = nil
  end
  return session
end

local function _test_await_choice_bridges_action_anim_into_wait_state()
  local g = support.new_game()
  g.turn.pending_choice = {
    id = 21,
    route_key = "secondary_confirm",
    allow_cancel = true,
    options = {
      { id = "buy_land", label = "buy" },
    },
  }
  local session = _new_await_session(g, {
    type = "choice_select",
    choice_id = 21,
    option_id = "buy_land",
    actor_role_id = g:current_player().id,
  })

  local original_resolve_choice = require("src.game.flow.turn.decision").resolve_choice
  require("src.game.flow.turn.decision").resolve_choice = function(game, choice, action)
    game.turn.action_anim = { seq = 7, kind = "move_effect" }
    return {
      after_action_anim = {
        next_state = "move_followup",
        next_args = {
          mode = "resume",
        },
      },
    }
  end

  local res = await.choice(session, { next_state = "post_action", next_args = { player = g:current_player() } })
  require("src.game.flow.turn.decision").resolve_choice = original_resolve_choice

  assert(res and res.next_state == "wait_action_anim", "choice should bridge action anim into wait_action_anim")
  assert(res.next_args and res.next_args.next_state == "move_followup", "choice should preserve move_followup target")
  assert(g.turn.move_followup_pending == true, "choice should mark move_followup_pending when action anim exists")
end

local function _test_await_action_anim_advances_through_queue()
  local g = support.new_game()
  g.turn.action_anim = { seq = 8, kind = "roll" }
  g.turn.action_anim_queue = {
    { seq = 9, kind = "roll" },
  }
  local session = _new_await_session(g, {
    type = "action_anim_done",
    seq = 8,
  })

  local first = await.action_anim(session, { next_state = "done", next_args = {} })
  assert(first and first.wait == true, "first completion should wait for queued action anim")
  assert(g.turn.action_anim and g.turn.action_anim.seq == 9, "queued action anim should become active")

  session._action = {
    type = "action_anim_done",
    seq = 9,
  }
  local second = await.action_anim(session, { next_state = "done", next_args = { ok = true } })
  assert(second and second.next_state == "done", "queue drain should resume original next state")
  assert(second.next_args and second.next_args.ok == true, "queue drain should preserve next args")
end

local function _test_await_seconds_waits_until_elapsed()
  local session = { _seconds_wait = {} }
  local times = { 10, 12, 15 }
  local index = 0
  local function now_fn()
    index = index + 1
    return times[index]
  end

  local first = await.seconds(session, 4, { key = "k", now_fn = now_fn })
  local second = await.seconds(session, 4, { key = "k", now_fn = now_fn })
  local third = await.seconds(session, 4, { key = "k", now_fn = now_fn })

  assert(first and first.wait == true, "first wait should arm timer")
  assert(second and second.wait == true, "insufficient elapsed time should keep waiting")
  assert(third and third.done == true, "elapsed time should complete wait")
  assert(session._seconds_wait.k == nil, "completed wait should clear timer key")
end

---------------------------------------------------------------------------
-- suite export
---------------------------------------------------------------------------
return {
  name = "gameplay.coroutine",
  tests = {
    {
      name = "turn_engine_defaults_to_coroutine_mode",
      run = _test_turn_engine_defaults_to_coroutine_mode,
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
      name = "coroutine_mode_resolves_inter_turn_wait",
      run = _test_coroutine_mode_resolves_inter_turn_wait,
    },
    {
      name = "coroutine_mode_resolves_wait_landing_visual",
      run = _test_coroutine_mode_resolves_wait_landing_visual,
    },
    {
      name = "coroutine_mode_full_turn_lifecycle",
      run = _test_coroutine_mode_full_turn_lifecycle,
    },
    {
      name = "await_choice_bridges_action_anim_into_wait_state",
      run = _test_await_choice_bridges_action_anim_into_wait_state,
    },
    {
      name = "await_action_anim_advances_through_queue",
      run = _test_await_action_anim_advances_through_queue,
    },
    {
      name = "await_seconds_waits_until_elapsed",
      run = _test_await_seconds_waits_until_elapsed,
    },
  },
}
