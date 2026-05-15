local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_session(phases, opts)
  opts = opts or {}
  return {
    phases = phases or {},
    game = {
      turn = { turn_count = opts.turn_count or 0 },
      current_player = function() return { name = "P1" } end,
    },
    turn_mgr = opts.turn_mgr,
    current_state = opts.current_state,
    current_args = opts.current_args,
    mark_phase = function(self, name) self.last_phase = name end,
  }
end

local function _load_session_script_with_await(stub_await)
  package.loaded["src.turn.waits.await"] = stub_await
  package.loaded["src.turn.timing"] = nil
  return require("src.turn.timing")
end

local function _restore_modules()
  package.loaded["src.turn.waits.await"] = nil
  package.loaded["src.turn.timing"] = nil
end

describe("domain session_script extended coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)
  after_each(function() _restore_modules() end)

  it("wait handler returning {wait=true} yields and preserves state_name", function()
    local action_calls = 0
    local turn_script = _load_session_script_with_await({
      action = function(_, _) action_calls = action_calls + 1; return { wait = true } end,
      choice = function() return nil end,
      move_anim = function() return nil end,
      action_anim = function() return nil end,
      landing_visual = function() return nil end,
      detained = function() return nil end,
      inter_turn = function() return nil end,
    })
    local session = _make_session({}, { current_state = "wait_action", current_args = { tag = "first" } })
    local co = turn_script.create(session)
    local ok, yield_payload = coroutine.resume(co)
    assert(ok, "first resume should succeed")
    _assert_eq(action_calls, 1, "wait_action handler should run once")
    assert(type(yield_payload) == "table", "yield payload should be table")
    _assert_eq(yield_payload.kind, "wait", "yield kind should be 'wait'")
    _assert_eq(yield_payload.wait_state, "wait_action", "wait_state should match current_state")
    _assert_eq(session.wait_state, "wait_action", "session.wait_state should be set on yield")
    _assert_eq(session.finished, nil, "session should not be finished after yield")
  end)

  it("wait handler returning {wait=false, next_state=...} transitions without yield", function()
    local visited = {}
    local turn_script = _load_session_script_with_await({
      action = function() return nil end,
      choice = function(_, _)
        return { wait = false, next_state = "after_choice", next_args = { picked = "opt_a" } }
      end,
      move_anim = function() return nil end,
      action_anim = function() return nil end,
      landing_visual = function() return nil end,
      detained = function() return nil end,
      inter_turn = function() return nil end,
    })
    local session = _make_session({
      after_choice = function(_, args)
        visited[#visited + 1] = { phase = "after_choice", args = args }
        return nil
      end,
    }, { current_state = "wait_choice" })
    local co = turn_script.create(session)
    local ok = coroutine.resume(co)
    assert(ok, "coroutine should complete without error")
    _assert_eq(session.finished, true, "session should finish")
    _assert_eq(#visited, 1, "after_choice should run once")
    _assert_eq(visited[1].phase, "after_choice", "should transition to after_choice")
    _assert_eq(visited[1].args.picked, "opt_a", "next_args should be forwarded")
  end)

  it("_resolve_phase_handler falls back to require for move_followup when phases lack it", function()
    local turn_script = require("src.turn.timing")
    local move_followup = require("src.turn.phases.move_followup")
    local saved_run = move_followup.run
    local run_calls = 0
    move_followup.run = function(_, _) run_calls = run_calls + 1; return nil end
    local session = _make_session({}, { current_state = "move_followup" })
    local co = turn_script.create(session)
    local ok = coroutine.resume(co)
    move_followup.run = saved_run
    assert(ok, "coroutine should complete")
    _assert_eq(run_calls, 1, "move_followup.run should be invoked via require fallback")
    _assert_eq(session.finished, true, "session should finish")
  end)

  it("start state triggers turn_decision.log_turn_start", function()
    local turn_script = require("src.turn.timing")
    local turn_decision = require("src.turn.waits.decision")
    local saved = turn_decision.log_turn_start
    local logged_games = {}
    turn_decision.log_turn_start = function(g) logged_games[#logged_games + 1] = g end
    local session = _make_session({
      start = function(_, _) return nil end,
    })
    local co = turn_script.create(session)
    local ok = coroutine.resume(co)
    turn_decision.log_turn_start = saved
    assert(ok, "coroutine should complete")
    _assert_eq(#logged_games, 1, "log_turn_start should be called once for 'start' state")
    _assert_eq(logged_games[1], session.game, "log_turn_start should receive session.game")
  end)

  it("yield can be resumed; resumed coroutine continues execution", function()
    local action_step = 0
    local turn_script = _load_session_script_with_await({
      action = function(_, _)
        action_step = action_step + 1
        if action_step == 1 then return { wait = true } end
        return { wait = false, next_state = "done", next_args = nil }
      end,
      choice = function() return nil end,
      move_anim = function() return nil end,
      action_anim = function() return nil end,
      landing_visual = function() return nil end,
      detained = function() return nil end,
      inter_turn = function() return nil end,
    })
    local session = _make_session({
      done = function(_, _) return nil end,
    }, { current_state = "wait_action" })
    local co = turn_script.create(session)
    local ok1 = coroutine.resume(co)
    assert(ok1, "first resume should succeed")
    _assert_eq(session.finished, nil, "session not finished after yield")
    local ok2 = coroutine.resume(co)
    assert(ok2, "second resume should succeed")
    _assert_eq(session.finished, true, "session finished after resume completes flow")
    _assert_eq(action_step, 2, "wait_action handler should be invoked twice")
  end)

  it("missing phase handler raises assertion error", function()
    local turn_script = require("src.turn.timing")
    local session = _make_session({}, { current_state = "no_such_phase" })
    local co = turn_script.create(session)
    local ok, err = coroutine.resume(co)
    _assert_eq(ok, false, "missing handler should error")
    assert(tostring(err):find("missing phase handler") ~= nil,
      "error should mention 'missing phase handler', got: " .. tostring(err))
  end)
end)
