local support = require("support.gameplay_support")
local turn_engine = require("src.turn.loop.scheduler_runtime")
local landing_visual_hold = require("src.state.landing_visual_hold")
local wait_callbacks = require("src.turn.waits.callback_registry")
local await = require("src.turn.waits.await")
local logger = require("src.core.utils.logger")
local tip_queue = require("src.core.utils.tip_queue")

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
  assert(wait_callbacks.is_wait_ready(g, "landing_visual") == true, "wait_landing_visual should arm release callback")

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
    self.game.turn.phase = name
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

  local original_resolve_choice = require("src.turn.waits.decision").resolve_choice
  require("src.turn.waits.decision").resolve_choice = function(game, choice, action)
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
  require("src.turn.waits.decision").resolve_choice = original_resolve_choice

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

local function _test_await_action_anim_defers_callback_until_queue_drains()
  local g = support.new_game()
  local callback_runs = 0
  local after_action_anim = wait_callbacks.callback_keys.after_action_anim
  g.turn.action_anim = { seq = 8, kind = "roadblock_trigger" }
  g.turn.action_anim_queue = {
    { seq = 9, kind = "mine_trigger" },
  }
  wait_callbacks.register(g, after_action_anim, function()
    callback_runs = callback_runs + 1
    return "move_followup", {
      mode = "apply_location_effects",
      next_state = "end_turn",
      next_args = { ok = true },
    }
  end)
  local session = _new_await_session(g, {
    type = "action_anim_done",
    seq = 8,
  })

  local first = await.action_anim(session, { next_state = "done", next_args = {} })
  assert(first and first.wait == true, "first completion should keep waiting while queued action anim remains")
  assert(g.turn.phase == "wait_action_anim", "first completion should keep phase in wait_action_anim")
  assert(callback_runs == 0, "continuation should not run before queued action anim drains")
  assert(wait_callbacks.peek(g, after_action_anim) ~= nil, "continuation should remain registered while queue is not empty")
  assert(g.turn.action_anim and g.turn.action_anim.seq == 9, "queued action anim should become active before continuation runs")

  session._action = {
    type = "action_anim_done",
    seq = 9,
  }
  local second = await.action_anim(session, { next_state = "done", next_args = {} })
  assert(callback_runs == 1, "continuation should run after queued action anim drains")
  assert(wait_callbacks.peek(g, after_action_anim) == nil, "continuation should be consumed after queue drain")
  assert(second and second.next_state == "move_followup", "queue drain should resume continuation target")
  assert(second.next_args and second.next_args.mode == "apply_location_effects",
    "queue drain should preserve continuation args")
end

local function _test_await_move_anim_waits_for_matching_seq()
  local g = support.new_game()
  g.turn.move_anim = { seq = 11, player_id = g:current_player().id }
  local session = _new_await_session(g, {
    type = "move_anim_done",
    seq = 99,
  })

  local first = await.move_anim(session, { next_state = "done", next_args = { ok = true } })
  assert(first and first.wait == true, "mismatched move_anim seq should keep waiting")
  assert(g.turn.move_anim and g.turn.move_anim.seq == 11, "mismatched move_anim seq should keep active anim")

  session._action = {
    type = "move_anim_done",
    seq = 11,
  }
  local second = await.move_anim(session, { next_state = "done", next_args = { ok = true } })
  assert(second and second.next_state == "done", "matching move_anim seq should resume next state")
  assert(second.next_args and second.next_args.ok == true, "move_anim should preserve next args")
  assert(g.turn.move_anim == nil, "matching move_anim seq should clear active anim")
end

local function _test_await_move_anim_debug_log_reports_pending_action_details()
  local g = support.new_game()
  g.turn.phase = "wait_move_anim"
  g.turn.move_anim = { seq = 21 }
  local session = _new_await_session(g, {
    type = "move_anim_done",
    seq = 99,
  })
  local captured = nil
  local original_enabled = logger.is_anim_debug_enabled
  local original_log = logger.info_unlimited
  logger.is_anim_debug_enabled = function()
    return true
  end
  logger.info_unlimited = function(...)
    captured = table.concat({ ... }, "|")
  end

  local ok, err = pcall(function()
    local res = await.move_anim(session, { next_state = "done", next_args = {} })
    assert(res and res.wait == true, "mismatched move_anim seq should still wait while logging")
  end)

  logger.is_anim_debug_enabled = original_enabled
  logger.info_unlimited = original_log
  assert(ok, err)
  assert(captured and captured:find("await_move_anim", 1, true) ~= nil, "move_anim debug log should include wait event name")
  assert(captured:find("phase=wait_move_anim", 1, true) ~= nil, "move_anim debug log should include phase")
  assert(captured:find("anim_seq=21", 1, true) ~= nil, "move_anim debug log should include anim seq")
  assert(captured:find("pending_action_seq=99", 1, true) ~= nil, "move_anim debug log should include pending action seq")
end

local function _test_await_landing_visual_marks_release_pending_after_wait()
  local g = support.new_game()
  landing_visual_hold.start(g)
  local session = _new_await_session(g)

  local first = await.landing_visual(session, { next_state = "done", next_args = { ok = true } })
  assert(first and first.wait == true, "landing visual should wait on first entry")
  assert(wait_callbacks.pending_wait_seq(g, "landing_visual") ~= nil, "landing visual should arm wait state")
  assert(wait_callbacks.is_wait_ready(g, "landing_visual") == true, "landing visual test scheduler should mark wait ready")

  local second = await.landing_visual(session, { next_state = "done", next_args = { ok = true } })
  assert(second and second.next_state == "done", "landing visual should resume after timer fires")
  assert(second.next_args and second.next_args.ok == true, "landing visual should preserve next args")
  assert(g.turn.landing_visual_release_pending == true, "landing visual should mark release pending on completion")
end

local function _test_await_inter_turn_wait_clears_action_and_advances_player()
  local g = support.new_game()
  g.turn.inter_turn_wait_active = true
  local next_calls = 0
  local session = _new_await_session(g, {
    type = "noop",
  })
  function session:next_player()
    next_calls = next_calls + 1
    self.game.turn.current_player_index = 2
  end

  local first = await.inter_turn(session, { resumed = true })
  assert(first and first.wait == true, "active inter-turn wait should keep waiting")
  assert(session._action == nil, "active inter-turn wait should clear pending action")

  g.turn.inter_turn_wait_active = false
  local second = await.inter_turn(session, { resumed = true })
  assert(second and second.next_state == "start", "completed inter-turn wait should resume at start")
  assert(second.next_args and second.next_args.resumed == true, "inter-turn wait should preserve args")
  assert(next_calls == 1, "inter-turn wait should advance to next player once")
  assert(g.turn.current_player_index == 2, "inter-turn wait should move to next player")
end

local function _test_await_inter_turn_wait_blocks_until_tip_queue_drains()
  local g = support.new_game()
  local next_calls = 0
  local timers = {}
  local session = _new_await_session(g, {
    type = "noop",
  })
  function session:next_player()
    next_calls = next_calls + 1
    self.game.turn.current_player_index = 2
  end

  logger.clear()
  tip_queue.clear()
  tip_queue.configure_runtime({
    presenter = function() end,
    scheduler = function(delay, fn)
      timers[#timers + 1] = { delay = delay, fn = fn }
      return true
    end,
    test_mode = false,
  })

  local ok, err = pcall(function()
    tip_queue.enqueue({
      text = "pending inter-turn tip",
      duration = 1.0,
      dedupe_key = "inter_turn_tip",
      blocks_inter_turn = true,
      source = "test.await_inter_turn",
    })

    local first = await.inter_turn(session, { resumed = true })
    assert(first and first.wait == true, "pending tips should keep inter-turn wait blocked")
    assert(next_calls == 0, "pending tips should not advance player")

    timers[1].fn()

    local second = await.inter_turn(session, { resumed = true })
    assert(second and second.next_state == "start", "drained tips should allow inter-turn resume")
    assert(next_calls == 1, "drained tips should advance player once")
    assert(g.turn.current_player_index == 2, "drained tips should move to next player")
  end)

  tip_queue.configure_runtime({
    clear_presenter = true,
    clear_scheduler = true,
  })
  tip_queue.clear()
  logger.clear()
  if not ok then
    error(err)
  end
end

local function _test_turn_script_wait_move_anim_yields_and_resumes()
  local g = support.new_game()
  g.turn.move_anim = { seq = 31 }
  local session = _new_await_session(g, {
    type = "move_anim_done",
    seq = 99,
  })
  session.current_state = "wait_move_anim"
  session.current_args = {
    next_state = "done",
    next_args = { ok = true },
  }
  session.phases = {
    done = function()
      return nil
    end,
  }

  local co = require("src.turn.timing.session_script").create(session)
  local ok1, yielded = coroutine.resume(co)
  assert(ok1 == true, "turn_script should enter wait_move_anim")
  assert(yielded and yielded.kind == "wait" and yielded.wait_state == "wait_move_anim",
    "turn_script should yield while waiting on move_anim")

  session._action = {
    type = "move_anim_done",
    seq = 31,
  }
  local ok2 = coroutine.resume(co)
  assert(ok2 == true, "turn_script should resume after matching move_anim_done")
  assert(session.finished == true, "turn_script should finish after resuming to done")
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
-- wait_action: AI player resolves immediately
---------------------------------------------------------------------------
local function _test_await_action_resolves_immediately_for_ai_player()
  local g = support.new_game({ ai = { [1] = true, [2] = true } })
  local session = _new_await_session(g)

  local res = await.action(session, { next_state = "roll", next_args = { player = g:current_player() } })
  assert(res and res.next_state == "roll", "AI player should resolve wait_action immediately")
  assert(session.marked_phase == "wait_action", "wait_action should mark phase")
end

---------------------------------------------------------------------------
-- wait_action: human player yields without pending action
---------------------------------------------------------------------------
local function _test_await_action_yields_for_human_player()
  local g = support.new_game({ ai = { [2] = true } })
  local session = _new_await_session(g)

  local res = await.action(session, { next_state = "roll", next_args = { player = g:current_player() } })
  assert(res and res.wait == true, "human player should yield at wait_action")
  assert(session.marked_phase == "wait_action", "wait_action should mark phase")
end

---------------------------------------------------------------------------
-- wait_action: human player resolves with pending action
---------------------------------------------------------------------------
local function _test_await_action_resolves_for_human_player_with_pending_action()
  local g = support.new_game({ ai = { [2] = true } })
  local session = _new_await_session(g, { type = "ui_button", id = "next" })

  local res = await.action(session, { next_state = "roll", next_args = { player = g:current_player() } })
  assert(res and res.next_state == "roll", "human player with pending action should resolve wait_action")
end

---------------------------------------------------------------------------
-- wait_action: coroutine engine integration
---------------------------------------------------------------------------
local function _test_coroutine_mode_resolves_wait_action()
  local g = support.new_game({ ai = { [2] = true } })

  g.turn_engine = turn_engine:new(g, {
    start = function()
      return "wait_action", {
        player = g:current_player(),
        next_state = "done",
        next_args = {},
      }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  assert(g.turn.phase == "wait_action", "human player should enter wait_action")

  g:advance_turn()
  assert(g.turn.phase == "wait_action", "tick advance without action should stay in wait_action")

  g:dispatch_action({ type = "ui_button", id = "next" })
  assert(g.turn.phase ~= "wait_action", "dispatch action should leave wait_action")
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
      name = "await_action_anim_defers_callback_until_queue_drains",
      run = _test_await_action_anim_defers_callback_until_queue_drains,
    },
    {
      name = "await_move_anim_waits_for_matching_seq",
      run = _test_await_move_anim_waits_for_matching_seq,
    },
    {
      name = "await_move_anim_debug_log_reports_pending_action_details",
      run = _test_await_move_anim_debug_log_reports_pending_action_details,
    },
    {
      name = "await_landing_visual_marks_release_pending_after_wait",
      run = _test_await_landing_visual_marks_release_pending_after_wait,
    },
    {
      name = "await_inter_turn_wait_clears_action_and_advances_player",
      run = _test_await_inter_turn_wait_clears_action_and_advances_player,
    },
    {
      name = "await_inter_turn_wait_blocks_until_tip_queue_drains",
      run = _test_await_inter_turn_wait_blocks_until_tip_queue_drains,
    },
    {
      name = "turn_script_wait_move_anim_yields_and_resumes",
      run = _test_turn_script_wait_move_anim_yields_and_resumes,
    },
    {
      name = "await_seconds_waits_until_elapsed",
      run = _test_await_seconds_waits_until_elapsed,
    },
    {
      name = "await_action_resolves_immediately_for_ai_player",
      run = _test_await_action_resolves_immediately_for_ai_player,
    },
    {
      name = "await_action_yields_for_human_player",
      run = _test_await_action_yields_for_human_player,
    },
    {
      name = "await_action_resolves_for_human_player_with_pending_action",
      run = _test_await_action_resolves_for_human_player_with_pending_action,
    },
    {
      name = "coroutine_mode_resolves_wait_action",
      run = _test_coroutine_mode_resolves_wait_action,
    },
  },
}
