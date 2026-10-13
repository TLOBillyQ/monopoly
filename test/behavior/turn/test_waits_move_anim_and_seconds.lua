local check = require("luassert")
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

describe("TestWaitsMoveAnimAndSeconds", function()

it("test_move_anim_debug_logs_fields_and_waits_for_matching_action", function()
  local game = { turn = { phase = "move", move_anim = { seq = 7 } }, dirty = {} }
  local session = _make_session(game, { type = "move_anim_done", seq = 8 })
  local captured
  support.with_patches({
    { target = move_anim_debug, key = "enabled", value = function() return true end },
    { target = move_anim_debug, key = "log", value = function(...) captured = { ... } end },
  }, function()
    local result = move_anim_wait.move_anim(session, { next_state = "done" })
    check.same(result.wait, true)
  end)
  check.same(captured, {
    "await_move_anim",
    "phase=move",
    "anim_seq=7",
    "pending_action_type=move_anim_done",
    "pending_action_seq=8",
  })
end)

it("test_move_anim_matching_action_clears_anim_and_advances", function()
  local game = { turn = { move_anim = { seq = 7 } }, dirty = {} }
  local session = _make_session(game, { type = "move_anim_done", seq = 7 })

  local result = move_anim_wait.move_anim(session, {
    next_state = "done",
    next_args = { resumed = true },
  })

  check.is_nil(game.turn.move_anim)
  check.same(result.next_state, "done")
  check.same(result.next_args, { resumed = true })
  check.same(game.dirty.turn, true)
end)

it("test_seconds_nonpositive_or_invalid_clock_finishes_immediately", function()
  local session = _make_session({ turn = {} })

  check.same(seconds_wait.seconds(session, 0), { done = true })
  check.same(seconds_wait.seconds(session, 1, {}), { done = true })
  check.same(seconds_wait.seconds(session, 1, {
    now_fn = function() error("clock failed") end,
  }), { done = true })
  check.same(seconds_wait.seconds(session, 1, {
    now_fn = function() return "later" end,
  }), { done = true })
end)

it("test_seconds_tracks_each_key_until_elapsed", function()
  local now = 10
  local session = _make_session({ turn = {} })
  local opts = {
    key = "inter_turn",
    now_fn = function() return now end,
  }

  check.same(seconds_wait.seconds(session, 2, opts), { wait = true })
  now = 11
  check.same(seconds_wait.seconds(session, 2, opts), { wait = true })
  now = 12
  check.same(seconds_wait.seconds(session, 2, opts), { done = true })
  check.is_nil(session._seconds_wait.inter_turn)
end)

end)
