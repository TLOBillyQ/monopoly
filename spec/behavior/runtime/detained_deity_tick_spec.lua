-- CAPTURE-TEST: locks current detained-player deity-tick behavior. Do not change assertions without understanding the behavioral impact.
---@diagnostic disable: undefined-field

local support = require("support.test_profile_support")
local phase_registry = require("src.turn.phases.registry")
local waits = require("src.turn.waits.await.simple_waits")

local function _new_await_session(game)
  local session = { game = game }

  function session:mark_phase(name)
    self.marked_phase = name
  end

  function session:clear_pending_action()
  end

  return session
end

describe("runtime.detained_deity_tick", function()
  it("detained_player_deity_ticks_after_detained_turn", function()
    local game = support.apply_profile("hospital")
    local player = game.players[1]

    game:set_player_status(player, "stay_turns", 1)
    game:set_player_status(player, "deity", { type = "poor", remaining = 5 })

    local phases = phase_registry.build_default_phases()
    local next_state, next_args = phases.start({ game = game })

    assert.are.equal("detained_wait", next_state)
    assert.are.equal(0, player.status.stay_turns)

    local session = _new_await_session(game)
    local waiting = waits.detained(session, next_args)
    assert.are.equal(true, waiting.wait)

    game.turn.detained_wait_active = false
    local resumed = waits.detained(session, next_args)
    assert.are.equal("end_turn", resumed.next_state)

    phases.end_turn({ game = game }, resumed.next_args)

    assert.are.equal(4, player.status.deity.remaining)
  end)
end)
