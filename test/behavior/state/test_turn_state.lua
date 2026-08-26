local lu = require("luaunit")
local turn_state = require("src.state.turn_state")

local function _game()
  return { turn = {}, dirty = {} }
end

TestTurnState = {}

function TestTurnState:test_queue_action_anim_starts_seq_at_one()
  local g = _game()
  local payload = { kind = "mine_trigger" }
  local out = turn_state.queue_action_anim(g, payload)
  lu.assertEvalToTrue(out.seq == 1, "first queued anim gets seq 1 (kills `or 0` -> `or 1` and `+ 1` -> `+ 0`)")
  lu.assertEvalToTrue(g.turn.action_anim_seq == 1, "action_anim_seq tracked")
end

function TestTurnState:test_queue_action_anim_increments_seq()
  local g = _game()
  turn_state.queue_action_anim(g, { kind = "a" })
  local payload = { kind = "b" }
  turn_state.queue_action_anim(g, payload)
  lu.assertEvalToTrue(payload.seq == 2, "second queued anim gets seq 2 (kills `+ 1` -> `- 1`)")
end

function TestTurnState:test_queue_action_anim_occupies_slot_then_queues()
  local g = _game()
  local first = turn_state.queue_action_anim(g, { kind = "a" })
  local second = turn_state.queue_action_anim(g, { kind = "b" })
  lu.assertEvalToTrue(g.turn.action_anim == first, "first anim occupies the current slot")
  lu.assertEvalToTrue(#g.turn.action_anim_queue == 1, "second anim goes to the queue")
  lu.assertEvalToTrue(g.turn.action_anim_queue[1] == second, "queue holds the second anim")
end

function TestTurnState:test_queue_move_anim_starts_seq_at_one()
  local g = _game()
  local payload = { kind = "move" }
  local out = turn_state.queue_move_anim(g, payload)
  lu.assertEvalToTrue(out.seq == 1,
    "first move anim gets seq 1 (kills `or 0` -> `or 1` and `+ 1` -> `+ 0` and `or` -> `and`)")
  lu.assertEvalToTrue(g.turn.move_anim_seq == 1, "move_anim_seq tracked")
end

function TestTurnState:test_queue_move_anim_increments_seq_and_replaces_current()
  local g = _game()
  turn_state.queue_move_anim(g, { kind = "a" })
  local payload = { kind = "b" }
  turn_state.queue_move_anim(g, payload)
  lu.assertEvalToTrue(payload.seq == 2, "second move anim gets seq 2 (kills `+ 1` -> `- 1`)")
  lu.assertEvalToTrue(g.turn.move_anim == payload, "move anim replaces the current slot")
end

function TestTurnState:test_pending_choice_returns_turn_pending_choice()
  local g = _game()
  lu.assertEvalToTrue(turn_state.pending_choice(g) == nil, "nil pending choice")
  g.turn.pending_choice = { id = 1 }
  lu.assertEvalToTrue(turn_state.pending_choice(g).id == 1, "pending choice passthrough")
end

return TestTurnState
