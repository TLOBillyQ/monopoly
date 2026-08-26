local lu = require("luaunit")
local support = require("test.support.shared_support")
local move_anim_debug = require("src.foundation.move_anim_debug")
local move_anim_wait = require("src.turn.waits.await_move_anim")
local seconds_wait = require("src.turn.waits.await_seconds")

local function _make_session(game, pending_action)
  local session = {
    game = game,
    _pending_action = pending_action,
    _seconds_wait = {},
  }
  function session:mark_phase(phase)
    self.game.turn.phase = phase
  end
  function session:peek_pending_action()
    return self._pending_action
  end
  function session:take_pending_action()
    local action = self._pending_action
    self._pending_action = nil
    return action
  end
  return session
end

TestWaitsMoveAnimAndSeconds = {}

function TestWaitsMoveAnimAndSeconds:test_move_anim_debug_logs_fields_and_waits_for_matching_action()
  local game = { turn = { phase = "move", move_anim = { seq = 7 } }, dirty = {} }
  local session = _make_session(game, { type = "move_anim_done", seq = 8 })
  local captured
  support.with_patches({
    { target = move_anim_debug, key = "enabled", value = function() return true end },
    { target = move_anim_debug, key = "log", value = function(...) captured = { ... } end },
  }, function()
    local result = move_anim_wait.move_anim(session, { next_state = "done" })
    lu.assertEquals(result.wait, true)
  end)
  lu.assertEquals(captured, {
    "await_move_anim",
    "phase=move",
    "anim_seq=7",
    "pending_action_type=move_anim_done",
    "pending_action_seq=8",
  })
end

function TestWaitsMoveAnimAndSeconds:test_move_anim_matching_action_clears_anim_and_advances()
  local game = { turn = { move_anim = { seq = 7 } }, dirty = {} }
  local session = _make_session(game, { type = "move_anim_done", seq = 7 })

  local result = move_anim_wait.move_anim(session, {
    next_state = "done",
    next_args = { resumed = true },
  })

  lu.assertNil(game.turn.move_anim)
  lu.assertEquals(result.next_state, "done")
  lu.assertEquals(result.next_args, { resumed = true })
  lu.assertEquals(game.dirty.turn, true)
end

function TestWaitsMoveAnimAndSeconds:test_seconds_nonpositive_or_invalid_clock_finishes_immediately()
  local session = _make_session({ turn = {} })

  lu.assertEquals(seconds_wait.seconds(session, 0), { done = true })
  lu.assertEquals(seconds_wait.seconds(session, 1, {}), { done = true })
  lu.assertEquals(seconds_wait.seconds(session, 1, {
    now_fn = function() error("clock failed") end,
  }), { done = true })
  lu.assertEquals(seconds_wait.seconds(session, 1, {
    now_fn = function() return "later" end,
  }), { done = true })
end

function TestWaitsMoveAnimAndSeconds:test_seconds_tracks_each_key_until_elapsed()
  local now = 10
  local session = _make_session({ turn = {} })
  local opts = {
    key = "inter_turn",
    now_fn = function() return now end,
  }

  lu.assertEquals(seconds_wait.seconds(session, 2, opts), { wait = true })
  now = 11
  lu.assertEquals(seconds_wait.seconds(session, 2, opts), { wait = true })
  now = 12
  lu.assertEquals(seconds_wait.seconds(session, 2, opts), { done = true })
  lu.assertNil(session._seconds_wait.inter_turn)
end

return TestWaitsMoveAnimAndSeconds
