local tick_timeout = require("turn.timeout")
local turn_dispatch = require("turn.dispatch")
local patch = require("support.patch")
local assertions = require("support.assertions")

local function _test_popup_timeout_closes_even_when_input_blocked()
  local state = {
    ui = {
      input_blocked = true,
      popup_active = true,
      popup_seq = 101,
      popup_payload = {
        auto_close_seconds = 0.1,
      },
    },
    ui_modal_elapsed = 0,
    ui_modal_ref = nil,
    gameplay_loop_ports = {
      modal = {
        close_popup = function(ctx)
          ctx.ui.popup_active = false
        end,
      },
    },
  }

  tick_timeout.step_default_modal({}, state, 0.2)

  assertions.assert_equal(state.ui.popup_active, false, "popup should auto close even when input is blocked")
end

local function _test_choice_timeout_supports_explicit_timeout_strategy()
  local game = {
    players = {
      [1] = { id = 1 },
    },
    turn = {
      pending_choice = {
        id = 7,
        kind = "test",
        options = { { id = 11, label = "a" } },
      },
      current_player_index = 1,
    },
    current_player = function(self)
      return self.players[self.turn.current_player_index]
    end,
  }
  local state = {
    pending_choice = nil,
    pending_choice_elapsed = 0,
    pending_choice_id = nil,
  }
  local dispatched = nil

  patch.with_patches({
    {
      target = turn_dispatch,
      key = "dispatch_action",
      value = function(_, _, action)
        dispatched = action
      end,
    },
  }, function()
    tick_timeout.step_choice_timeout(game, state, 0.11, {
      on_pending_choice = function() end,
      is_choice_active = function()
        return true
      end,
      get_timeout_seconds = function()
        return 0.1
      end,
      build_action = function(_, _, choice)
        return {
          type = "choice_select",
          choice_id = choice.id,
          option_id = 11,
        }
      end,
    })
  end)

  assertions.assert_truthy(dispatched ~= nil and dispatched.type == "choice_select",
    "explicit timeout strategy should dispatch choice_select")
  assertions.assert_equal(dispatched.choice_id, 7, "explicit timeout strategy should use pending choice id")
end

local function _test_tick_timeout_default_policy_isolation()
  local policy = tick_timeout.default_policy()
  policy.choice.get_timeout_seconds = function()
    return 999
  end
  local fresh_policy = tick_timeout.default_policy()
  local timeout = fresh_policy.choice.get_timeout_seconds()
  assertions.assert_truthy(timeout ~= 999, "default policy should not be mutated by external override")
end

return {
  layer = "regression",
  domain = "timeout_modal_choice",
  cases = {
    {
      id = "given_input_blocked_popup_when_step_default_modal_then_popup_still_auto_closes",
      desc = "popup timeout closes under input lock",
      run = _test_popup_timeout_closes_even_when_input_blocked,
    },
    {
      id = "given_explicit_choice_timeout_strategy_when_step_choice_timeout_then_dispatch_expected_action",
      desc = "choice timeout supports explicit strategy",
      run = _test_choice_timeout_supports_explicit_timeout_strategy,
    },
    {
      id = "given_mutated_policy_copy_when_request_default_policy_then_returns_fresh_isolated_policy",
      desc = "default timeout policy is isolated",
      run = _test_tick_timeout_default_policy_isolation,
    },
  },
}
