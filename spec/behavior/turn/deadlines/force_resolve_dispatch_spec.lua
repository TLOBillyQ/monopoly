local support = require("spec.support.runtime_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local force_resolve = require("src.turn.deadlines")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local runtime_state = require("src.state.runtime")

describe("force_resolve dispatch path", function()
  it("auto choice action receives owner role and clears modal/output ports", function()
    local calls = {}
    local state = {}
    state._resolved_gameplay_loop_ports = {
      modal = {
        close_choice_modal = function(state_arg)
          calls[#calls + 1] = "close_modal"
          _assert_eq(state_arg, state, "modal close should receive state")
        end,
      },
      output = {
        clear_pending_choice = function(state_arg)
          calls[#calls + 1] = "clear_output"
          _assert_eq(state_arg, state, "output clear should receive state")
        end,
      },
    }
    runtime_state.ensure_all(state)
    local dispatched = nil
    local game = {
      players = { { id = 7 } },
      turn = {
        current_player_index = 1,
        pending_choice = { id = "stale_choice" },
      },
    }
    function game:dispatch_action(action)
      dispatched = action
    end

    local choice = {
      id = "choice_1",
      kind = "market_buy",
      owner_role_id = 42,
      options = {},
    }

    _with_patches({
      {
        target = choice_auto_policy,
        key = "decide",
        value = function()
          return { type = "choice_select", choice_id = "choice_1" }
        end,
      },
    }, function()
      force_resolve.resolve_choice(game, state, choice, "tick_timeout")
    end)

    _assert_eq(dispatched.type, "choice_select", "auto action should dispatch through game")
    _assert_eq(dispatched.actor_role_id, 42, "force resolve should fill actor from choice owner")
    _assert_eq(game.turn.pending_choice, nil, "stale pending choice should be cleared")
    _assert_eq(table.concat(calls, ","), "close_modal,clear_output", "modal and output ports should be closed")
  end)
end)
