-- pin：force-skip 超时路径把已算出的 action 透传给 resolve_choice，
-- choice_auto_policy.decide 恰调 1 次（非 2 次），终态仍走 force_skip。
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local deadlines = require("src.turn.deadlines")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

describe("resolve_choice precomputed_action passthrough", function()
  before_each(function() fallback_registry.reset() end)

  it("skips re-deciding when a precomputed force_skip is passed", function()
    local decide_calls = 0
    local state = {}
    runtime_state.ensure_all(state)
    local advanced = false
    local game = {
      players = { { id = 7 } },
      turn = { current_player_index = 1, pending_choice = nil },
      advance_turn = function() advanced = true end,
    }
    function game:dispatch_action() end
    local choice = { id = "c1", kind = "unregistered_kind", owner_role_id = 7, options = {} }

    _with_patches({
      { target = choice_auto_policy, key = "decide",
        value = function() decide_calls = decide_calls + 1
          return { type = "choice_force_skip", choice_id = "c1" } end },
    }, function()
      deadlines.resolve_choice(game, state, choice, "tick_timeout",
        { type = "choice_force_skip", choice_id = "c1" })
    end)

    _assert_eq(decide_calls, 0, "a precomputed action must skip choice_auto_policy.decide")
    assert(advanced == true, "an unresolved force_skip still advances the turn")
  end)

  it("still decides when no precomputed action is passed", function()
    local decide_calls = 0
    local state = {}
    runtime_state.ensure_all(state)
    local game = {
      players = { { id = 7 } },
      turn = { current_player_index = 1, pending_choice = nil },
      advance_turn = function() end,
    }
    function game:dispatch_action() end
    local choice = { id = "c2", kind = "unregistered_kind", owner_role_id = 7, options = {} }

    _with_patches({
      { target = choice_auto_policy, key = "decide",
        value = function() decide_calls = decide_calls + 1
          return { type = "choice_force_skip", choice_id = "c2" } end },
    }, function()
      deadlines.resolve_choice(game, state, choice, "tick_timeout")
    end)

    _assert_eq(decide_calls, 1, "without a precomputed action, decide is called once")
  end)
end)
