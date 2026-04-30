local action_anim_wait = require("src.turn.waits.await.action_anim_wait")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local _M = action_anim_wait._M_test

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_session(game, opts)
  opts = opts or {}
  local s = {
    game = game,
    _phase = nil,
    _pending_action = opts.pending_action,
    _cleared = false,
  }
  function s:mark_phase(p) self._phase = p end
  function s:clear_pending_action() self._cleared = true end
  function s:take_pending_action()
    local a = self._pending_action
    self._pending_action = nil
    return a
  end
  return s
end

local function _make_game(opts)
  opts = opts or {}
  local g = {
    turn = opts.turn or { action_anim = nil, action_anim_queue = {} },
    dirty = opts.dirty or { turn = false, any = false },
  }
  return g
end

-- _coalesce_head

local function test_coalesce_head_single_element_no_change()
  local q = { { kind = "cash_receive", amount = 10 } }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "single element queue should not be modified")
  _assert_eq(q[1].amount, 10, "amount should be unchanged")
end

local function test_coalesce_head_two_non_cash_no_merge()
  local q = { { kind = "other_kind", amount = 5 }, { kind = "cash_receive", amount = 3 } }
  _M._coalesce_head(q)
  _assert_eq(#q, 2, "non-cash head should not merge")
end

local function test_coalesce_head_two_cash_receive_merged()
  local q = {
    { kind = "cash_receive", amount = 10 },
    { kind = "cash_receive", amount = 20 },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "two cash_receive should merge into one")
  _assert_eq(q[1].amount, 30, "merged amount should be 10+20=30")
  _assert_eq(q[1].coalesced_count, 2, "coalesced_count should be 2")
end

local function test_coalesce_head_three_cash_then_other_merges_first_two()
  local q = {
    { kind = "cash_receive", amount = 5 },
    { kind = "cash_receive", amount = 7 },
    { kind = "other_kind", amount = 1 },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 2, "two cash_receive merged, other remains")
  _assert_eq(q[1].amount, 12, "merged amount should be 5+7=12")
  _assert_eq(q[2].kind, "other_kind", "second element should be the other kind")
end

local function test_coalesce_head_all_cash_merged()
  local q = {
    { kind = "cash_receive", amount = 1 },
    { kind = "cash_receive", amount = 2 },
    { kind = "cash_receive", amount = 3 },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "all cash_receive should merge into one")
  _assert_eq(q[1].amount, 6, "merged amount should be 1+2+3=6")
end

local function test_coalesce_head_nil_amounts_treated_as_zero()
  local q = {
    { kind = "cash_receive" },
    { kind = "cash_receive" },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "nil amounts should merge")
  _assert_eq(q[1].amount, 0, "nil amounts should sum to 0")
end

-- action_anim: idle path (no anim, no queued)

local function test_action_anim_idle_no_anim_clears_and_returns_next()
  local game = _make_game({ turn = { action_anim = nil, action_anim_queue = {} } })
  local session = _make_session(game, { pending_action = nil })
  local res = action_anim_wait.action_anim(session, { next_state = "done", next_args = { x = 1 } })
  _assert_eq(session._phase, "wait_action_anim", "should mark phase")
  _assert_eq(session._cleared, true, "should clear pending action")
  _assert_eq(res.next_state, "done", "should return provided next_state")
  _assert_eq(res.next_args.x, 1, "should return provided next_args")
end

local function test_action_anim_idle_no_args_returns_nil_next_state()
  local game = _make_game({ turn = { action_anim = nil, action_anim_queue = {} } })
  local session = _make_session(game)
  local res = action_anim_wait.action_anim(session, nil)
  _assert_eq(res.next_state, nil, "nil args should give nil next_state")
end

-- action_anim: queued next anim (idle + queued returns wait=true)

local function test_action_anim_queued_next_returns_wait()
  runtime_ports.configure({ wall_now_seconds = function() return 100.0 end })
  local game = _make_game({
    turn = {
      action_anim = nil,
      action_anim_queue = { { kind = "cash_receive", amount = 5 } },
    },
  })
  local session = _make_session(game)
  local res = action_anim_wait.action_anim(session, {})
  -- _next_action_anim pops the queue and sets action_anim; _resolve_action_anim_idle sees nil+queued
  -- Actually: _resolve_action_anim_wait: anim=nil (game.turn.action_anim nil before call)
  -- then _next_action_anim pops queue → sets game.turn.action_anim
  -- So anim becomes the popped entry, queued_next_anim=true, idle_res=nil (anim is not nil)
  -- Then we reach the action check path
  _assert_eq(res.wait, true, "anim present should return wait=true when action does not match")
  runtime_ports.reset_for_tests()
end

-- action_anim: anim present, action does not match → wait

local function test_action_anim_with_anim_no_matching_action_returns_wait()
  runtime_ports.configure({ wall_now_seconds = function() return 0.0 end })
  local game = _make_game({
    turn = {
      action_anim = { kind = "explode", started_at = 0.0, duration = 2.0 },
      action_anim_queue = {},
    },
  })
  local session = _make_session(game, { pending_action = nil })
  local res = action_anim_wait.action_anim(session, {})
  _assert_eq(res.wait, true, "no matching action should return wait=true")
  runtime_ports.reset_for_tests()
end

-- action_anim: anim timed out → complete and return next

local function test_action_anim_timed_out_completes_anim()
  local now_t = 100.0
  runtime_ports.configure({
    wall_now_seconds = function() return now_t end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local game = _make_game({
    turn = {
      action_anim = { kind = "explode", started_at = 0.0, duration = 1.0, seq = nil },
      action_anim_queue = {},
    },
  })
  local session = _make_session(game, { pending_action = { type = "unrelated" } })
  local res = action_anim_wait.action_anim(session, { next_state = "after_anim" })
  _assert_eq(session._cleared, true, "timed-out anim should clear pending action")
  _assert_eq(res.next_state, "after_anim", "should return next_state on timeout completion")
  _assert_eq(game.turn.action_anim, nil, "action_anim should be cleared after completion")
  runtime_ports.reset_for_tests()
end

-- action_anim: anim done action matches → complete

local function test_action_anim_done_action_matches_completes()
  runtime_ports.configure({
    wall_now_seconds = function() return 0.0 end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local anim = { kind = "explode", started_at = 0.0, duration = 2.0, seq = 7 }
  local game = _make_game({
    turn = {
      action_anim = anim,
      action_anim_queue = {},
    },
  })
  local done_action = { type = "action_anim_done", seq = 7 }
  local session = _make_session(game, { pending_action = done_action })
  local res = action_anim_wait.action_anim(session, { next_state = "move" })
  _assert_eq(game.turn.action_anim, nil, "action_anim should be cleared on done")
  _assert_eq(res.next_state, "move", "should return next_state after done")
  runtime_ports.reset_for_tests()
end

-- action_anim: done action with continuation callback

local function test_action_anim_done_with_continuation_uses_callback()
  runtime_ports.configure({
    wall_now_seconds = function() return 0.0 end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local anim = { kind = "explode", started_at = 0.0, duration = 2.0 }
  local game = _make_game({
    turn = { action_anim = anim, action_anim_queue = {} },
  })
  game.wait_callback_runtime = {
    callbacks = { after_action_anim = function() return "cont_state", { cont = true } end },
    seq_by_key = {},
    pending_seq_by_key = {},
    ready_seq_by_key = {},
  }
  local done_action = { type = "action_anim_done" }
  local session = _make_session(game, { pending_action = done_action })
  local res = action_anim_wait.action_anim(session, { next_state = "should_not_use" })
  _assert_eq(res.next_state, "cont_state", "continuation callback should override next_state")
  _assert_eq(res.next_args.cont, true, "continuation next_args should be returned")
  runtime_ports.reset_for_tests()
end

-- action_anim: timed-out with queued next → wait

local function test_action_anim_timed_out_with_queued_next_returns_wait()
  local now_t = 200.0
  runtime_ports.configure({
    wall_now_seconds = function() return now_t end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local game = _make_game({
    turn = {
      action_anim = { kind = "first", started_at = 0.0, duration = 1.0 },
      action_anim_queue = { { kind = "second" } },
    },
  })
  local session = _make_session(game, { pending_action = { type = "unrelated" } })
  local res = action_anim_wait.action_anim(session, {})
  _assert_eq(res.wait, true, "timeout with queued next should return wait=true for next anim")
  runtime_ports.reset_for_tests()
end

-- _mark_dirty via action_anim

local function test_action_anim_marks_game_dirty_when_anim_set()
  runtime_ports.configure({
    wall_now_seconds = function() return 0.0 end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local game = _make_game({
    turn = {
      action_anim = nil,
      action_anim_queue = { { kind = "cash_receive", amount = 5 } },
    },
  })
  local session = _make_session(game, { pending_action = nil })
  action_anim_wait.action_anim(session, {})
  _assert_eq(game.dirty.any, true, "game.dirty.any should be set when anim dequeued")
  _assert_eq(game.dirty.turn, true, "game.dirty.turn should be set when anim dequeued")
  runtime_ports.reset_for_tests()
end

-- _is_anim_timed_out: no started_at returns false (anim with done action)

local function test_action_anim_no_started_at_does_not_time_out()
  runtime_ports.configure({
    wall_now_seconds = function() return 1000.0 end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local anim = { kind = "explode", started_at = nil, duration = 2.0 }
  local game = _make_game({
    turn = { action_anim = anim, action_anim_queue = {} },
  })
  local done_action = { type = "action_anim_done" }
  local session = _make_session(game, { pending_action = done_action })
  -- no started_at → _is_anim_timed_out returns false → should proceed to done action check
  local res = action_anim_wait.action_anim(session, { next_state = "after" })
  _assert_eq(res.next_state, "after", "anim without started_at should not time out")
  runtime_ports.reset_for_tests()
end

-- seq mismatch → _is_matching_done_action returns false → wait

local function test_action_anim_done_seq_mismatch_returns_wait()
  runtime_ports.configure({
    wall_now_seconds = function() return 0.0 end,
    wall_diff_seconds = function(t1, t2) return t1 - t2 end,
  })
  local anim = { kind = "explode", started_at = 0.0, duration = 2.0, seq = 5 }
  local game = _make_game({
    turn = { action_anim = anim, action_anim_queue = {} },
  })
  local done_action = { type = "action_anim_done", seq = 99 }
  local session = _make_session(game, { pending_action = done_action })
  local res = action_anim_wait.action_anim(session, {})
  _assert_eq(res.wait, true, "seq mismatch should return wait=true")
  runtime_ports.reset_for_tests()
end

return {
  name = "domain action anim wait coverage",
  tests = {
    { name = "coalesce_head single element no change", run = test_coalesce_head_single_element_no_change },
    { name = "coalesce_head two non-cash no merge", run = test_coalesce_head_two_non_cash_no_merge },
    { name = "coalesce_head two cash_receive merged", run = test_coalesce_head_two_cash_receive_merged },
    { name = "coalesce_head three cash then other merges first two", run = test_coalesce_head_three_cash_then_other_merges_first_two },
    { name = "coalesce_head all cash merged", run = test_coalesce_head_all_cash_merged },
    { name = "coalesce_head nil amounts treated as zero", run = test_coalesce_head_nil_amounts_treated_as_zero },
    { name = "action_anim idle no anim clears and returns next", run = test_action_anim_idle_no_anim_clears_and_returns_next },
    { name = "action_anim idle no args returns nil next_state", run = test_action_anim_idle_no_args_returns_nil_next_state },
    { name = "action_anim queued next returns wait", run = test_action_anim_queued_next_returns_wait },
    { name = "action_anim with anim no matching action returns wait", run = test_action_anim_with_anim_no_matching_action_returns_wait },
    { name = "action_anim timed out completes anim", run = test_action_anim_timed_out_completes_anim },
    { name = "action_anim done action matches completes", run = test_action_anim_done_action_matches_completes },
    { name = "action_anim done with continuation uses callback", run = test_action_anim_done_with_continuation_uses_callback },
    { name = "action_anim timed out with queued next returns wait", run = test_action_anim_timed_out_with_queued_next_returns_wait },
    { name = "action_anim marks game dirty when anim set", run = test_action_anim_marks_game_dirty_when_anim_set },
    { name = "action_anim no started_at does not time out", run = test_action_anim_no_started_at_does_not_time_out },
    { name = "action_anim done seq mismatch returns wait", run = test_action_anim_done_seq_mismatch_returns_wait },
  },
}
