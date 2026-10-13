-- pin：force-skip 超时路径把已算出的 action 透传给 resolve_choice，
-- choice_auto_policy.decide 恰调 1 次（非 2 次），终态仍走 force_skip。
-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert

local support = require("test.support.shared_support")
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local _with_patches = support.with_patches

local deadlines = require("src.turn.deadlines")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

describe("TestDoubleDecide", function()

before_each(function()
  fallback_registry.reset()
end)

it("test_skips_re_deciding_when_a_precomputed_force_skip_is_passed", function()
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
  luassert.truthy(advanced == true, "an unresolved force_skip still advances the turn")
end)

it("test_still_decides_when_no_precomputed_action_is_passed", function()
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
