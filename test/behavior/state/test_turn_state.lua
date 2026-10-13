require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local turn_state = require("src.state.turn_state")

local function _game()
  return { turn = {}, dirty = {} }
end

describe("TestTurnState", function()

  it("test_queue_action_anim_starts_seq_at_one", function()
    local g = _game()
    local payload = { kind = "mine_trigger" }
    local out = turn_state.queue_action_anim(g, payload)
    luassert.truthy(out.seq == 1, "first queued anim gets seq 1 (kills `or 0` -> `or 1` and `+ 1` -> `+ 0`)")
    luassert.truthy(g.turn.action_anim_seq == 1, "action_anim_seq tracked")
  end)

  it("test_queue_action_anim_increments_seq", function()
    local g = _game()
    turn_state.queue_action_anim(g, { kind = "a" })
    local payload = { kind = "b" }
    turn_state.queue_action_anim(g, payload)
    luassert.truthy(payload.seq == 2, "second queued anim gets seq 2 (kills `+ 1` -> `- 1`)")
  end)

  it("test_queue_action_anim_occupies_slot_then_queues", function()
    local g = _game()
    local first = turn_state.queue_action_anim(g, { kind = "a" })
    local second = turn_state.queue_action_anim(g, { kind = "b" })
    luassert.truthy(g.turn.action_anim == first, "first anim occupies the current slot")
    luassert.truthy(#g.turn.action_anim_queue == 1, "second anim goes to the queue")
    luassert.truthy(g.turn.action_anim_queue[1] == second, "queue holds the second anim")
  end)

  it("test_queue_move_anim_starts_seq_at_one", function()
    local g = _game()
    local payload = { kind = "move" }
    local out = turn_state.queue_move_anim(g, payload)
    luassert.truthy(out.seq == 1, "first move anim gets seq 1 (kills `or 0` -> `or 1` and `+ 1` -> `+ 0` and `or` -> `and`)")
    luassert.truthy(g.turn.move_anim_seq == 1, "move_anim_seq tracked")
  end)

  it("test_queue_move_anim_increments_seq_and_replaces_current", function()
    local g = _game()
    turn_state.queue_move_anim(g, { kind = "a" })
    local payload = { kind = "b" }
    turn_state.queue_move_anim(g, payload)
    luassert.truthy(payload.seq == 2, "second move anim gets seq 2 (kills `+ 1` -> `- 1`)")
    luassert.truthy(g.turn.move_anim == payload, "move anim replaces the current slot")
  end)

  it("test_pending_choice_returns_turn_pending_choice", function()
    local g = _game()
    luassert.truthy(turn_state.pending_choice(g) == nil, "nil pending choice")
    g.turn.pending_choice = { id = 1 }
    luassert.truthy(turn_state.pending_choice(g).id == 1, "pending choice passthrough")
  end)

end)
