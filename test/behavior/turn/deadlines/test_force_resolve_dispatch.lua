-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert

local support = require("test.support.shared_support")
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local _with_patches = support.with_patches

local force_resolve = require("src.turn.deadlines")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

describe("TestForceResolveDispatch", function()

before_each(function()
  fallback_registry.reset()
end)

it("test_auto_choice_action_receives_owner_role_and_clears_modal_output_ports", function()
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
    find_player_by_id = function(_, id) return { id = id } end,
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

it("test_auto_choice_action_inherits_missing_choice_id_from_choice", function()
  local state = {}
  runtime_state.ensure_all(state)
  local dispatched = nil
  local game = {
    players = { { id = 7 } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    find_player_by_id = function(_, id) return { id = id } end,
  }
  function game:dispatch_action(action)
    dispatched = action
  end

  local choice = {
    id = "choice_from_timeout",
    kind = "market_buy",
    owner_role_id = 42,
    options = {},
  }

  _with_patches({
    {
      target = choice_auto_policy,
      key = "decide",
      value = function()
        return { type = "choice_select" }
      end,
    },
  }, function()
    force_resolve.resolve_choice(game, state, choice, "tick_timeout")
  end)

  _assert_eq(dispatched.choice_id, "choice_from_timeout", "missing auto action choice_id should be filled")
  _assert_eq(dispatched.actor_role_id, 42, "missing auto action actor should still be filled")
end)

it("test_auto_choice_action_fills_actor_from_current_player_when_choice_has_no_owner", function()
  local state = {}
  runtime_state.ensure_all(state)
  local dispatched = nil
  local game = {
    players = { { id = 7 } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
  }
  function game:dispatch_action(action)
    dispatched = action
  end

  local choice = {
    id = "choice_current_player",
    kind = "market_buy",
    options = {},
  }

  _with_patches({
    {
      target = choice_auto_policy,
      key = "decide",
      value = function()
        return { type = "choice_select" }
      end,
    },
  }, function()
    force_resolve.resolve_choice(game, state, choice, "tick_timeout")
  end)

  _assert_eq(dispatched.choice_id, "choice_current_player", "missing auto action choice_id should be filled")
  _assert_eq(dispatched.actor_role_id, 7, "missing actor should fall back to current player")
end)

it("test_force_skip_auto_action_can_dispatch_registered_fallback_choice_action", function()
  local state = {}
  runtime_state.ensure_all(state)
  local dispatched = nil
  local game = {
    players = { { id = 7 } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    find_player_by_id = function(_, id) return { id = id } end,
  }
  function game:dispatch_action(action)
    dispatched = action
  end

  fallback_registry.register("market_buy", function(_, choice)
    return { type = "choice_cancel", choice_id = choice.id }
  end)

  local choice = {
    id = "choice_fallback",
    kind = "market_buy",
    owner_role_id = 42,
    options = {},
  }

  _with_patches({
    {
      target = choice_auto_policy,
      key = "decide",
      value = function()
        return { type = "choice_force_skip" }
      end,
    },
  }, function()
    force_resolve.resolve_choice(game, state, choice, "tick_timeout")
  end)

  _assert_eq(dispatched.type, "choice_cancel", "force-skip auto result should allow registered fallback")
  _assert_eq(dispatched.choice_id, "choice_fallback", "fallback action should dispatch")
  _assert_eq(dispatched.actor_role_id, 42, "fallback action actor should be filled")
end)

it("test_non_force_skip_auto_action_does_not_use_registered_fallback", function()
  local state = {}
  runtime_state.ensure_all(state)
  local dispatched = nil
  local advanced = 0
  local game = {
    finished = false,
    players = { { id = 7 } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    find_player_by_id = function(_, id) return { id = id } end,
  }
  function game:dispatch_action(action)
    dispatched = action
  end
  function game:advance_turn()
    advanced = advanced + 1
  end

  fallback_registry.register("market_buy", function(_, choice)
    return { type = "choice_cancel", choice_id = choice.id }
  end)

  local choice = {
    id = "choice_no_fallback",
    kind = "market_buy",
    owner_role_id = 42,
    options = {},
  }

  _with_patches({
    {
      target = choice_auto_policy,
      key = "decide",
      value = function()
        return { type = "not_dispatchable" }
      end,
    },
  }, function()
    force_resolve.resolve_choice(game, state, choice, "tick_timeout")
  end)

  luassert.is_nil(dispatched)
  _assert_eq(advanced, 1, "non force-skip auto result should force skip instead of fallback")
end)


end)
