local support = require("test.support.shared_support")
local action_anim_wait = require("src.turn.waits.await_action_anim")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local _M = action_anim_wait

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

-- 原生 LuaUnit 迁移:describe 拍平为单个 Test* 类,describe 级 before_each /
-- after_each 翻成 setUp / tearDown,用例数与改写前一一对应(17 例)。

TestActionAnimWait = {}

function TestActionAnimWait:setUp()
  require("test.support.config_reset").reset_all()
end

function TestActionAnimWait:tearDown()
  -- 各用例结尾的 runtime_ports.reset_for_tests() 把共享端口基线拆到未配置态,
  -- 必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

function TestActionAnimWait:test_coalesce_head_single_element_no_change()
  local q = { { kind = "cash_receive", amount = 10 } }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "single element queue should not be modified")
  _assert_eq(q[1].amount, 10, "amount should be unchanged")
end

function TestActionAnimWait:test_coalesce_head_two_non_cash_no_merge()
  local q = { { kind = "other_kind", amount = 5 }, { kind = "cash_receive", amount = 3 } }
  _M._coalesce_head(q)
  _assert_eq(#q, 2, "non-cash head should not merge")
end

function TestActionAnimWait:test_coalesce_head_two_cash_receive_merged()
  local q = {
    { kind = "cash_receive", amount = 10 },
    { kind = "cash_receive", amount = 20 },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "two cash_receive should merge into one")
  _assert_eq(q[1].amount, 30, "merged amount should be 10+20=30")
  _assert_eq(q[1].coalesced_count, 2, "coalesced_count should be 2")
end

function TestActionAnimWait:test_coalesce_head_three_cash_then_other_merges_first_two()
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

function TestActionAnimWait:test_coalesce_head_all_cash_merged()
  local q = {
    { kind = "cash_receive", amount = 1 },
    { kind = "cash_receive", amount = 2 },
    { kind = "cash_receive", amount = 3 },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "all cash_receive should merge into one")
  _assert_eq(q[1].amount, 6, "merged amount should be 1+2+3=6")
end

function TestActionAnimWait:test_coalesce_head_nil_amounts_treated_as_zero()
  local q = {
    { kind = "cash_receive" },
    { kind = "cash_receive" },
  }
  _M._coalesce_head(q)
  _assert_eq(#q, 1, "nil amounts should merge")
  _assert_eq(q[1].amount, 0, "nil amounts should sum to 0")
end

function TestActionAnimWait:test_action_anim_idle_no_anim_clears_and_returns_next()
  local game = _make_game({ turn = { action_anim = nil, action_anim_queue = {} } })
  local session = _make_session(game, { pending_action = nil })
  local res = action_anim_wait.action_anim(session, { next_state = "done", next_args = { x = 1 } })
  _assert_eq(session._phase, "wait_action_anim", "should mark phase")
  _assert_eq(session._cleared, true, "should clear pending action")
  _assert_eq(res.next_state, "done", "should return provided next_state")
  _assert_eq(res.next_args.x, 1, "should return provided next_args")
end

function TestActionAnimWait:test_action_anim_idle_no_args_returns_nil_next_state()
  local game = _make_game({ turn = { action_anim = nil, action_anim_queue = {} } })
  local session = _make_session(game)
  local res = action_anim_wait.action_anim(session, nil)
  _assert_eq(res.next_state, nil, "nil args should give nil next_state")
end

function TestActionAnimWait:test_action_anim_queued_next_returns_wait()
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

function TestActionAnimWait:test_action_anim_with_anim_no_matching_action_returns_wait()
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

function TestActionAnimWait:test_action_anim_timed_out_completes_anim()
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

function TestActionAnimWait:test_action_anim_done_action_matches_completes()
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

function TestActionAnimWait:test_action_anim_done_with_continuation_uses_callback()
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

function TestActionAnimWait:test_action_anim_timed_out_with_queued_next_returns_wait()
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

function TestActionAnimWait:test_action_anim_marks_game_dirty_when_anim_set()
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

function TestActionAnimWait:test_action_anim_no_started_at_does_not_time_out()
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

function TestActionAnimWait:test_action_anim_done_seq_mismatch_returns_wait()
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


return TestActionAnimWait
