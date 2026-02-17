local runtime = require("turn.runtime")
local assertions = require("support.assertions")

local function _test_phase_input_blocked_flags()
  assertions.assert_equal(runtime.is_phase_input_blocked("wait_move_anim"), true)
  assertions.assert_equal(runtime.is_phase_input_blocked("wait_action_anim"), true)
  assertions.assert_equal(runtime.is_phase_input_blocked("detained_wait"), true)
  assertions.assert_equal(runtime.is_phase_input_blocked("start"), false)
end

local function _test_action_button_timer_resets_when_input_blocked()
  local state = {
    ui = {
      input_blocked = true,
      popup_active = false,
      choice_active = false,
      market_active = false,
    },
    action_button_active = true,
    action_button_elapsed = 1,
  }
  runtime.update_action_button_timer({
    game = {
      finished = false,
      turn = { pending_choice = nil, current_player_index = 1 },
      players = { [1] = { id = 1 } },
    },
    state = state,
    dt = 0.2,
    ports = {
      ui_sync = {
        get_ui_state = function(ctx)
          return ctx and ctx.ui or nil
        end,
        is_input_blocked = function(ctx)
          local ui = ctx and ctx.ui or nil
          return ui and ui.input_blocked == true or false
        end,
        is_popup_active = function() return false end,
        is_choice_active = function() return false end,
        is_market_active = function() return false end,
      },
    },
    dispatch_next = function()
      error("dispatch_next should not be called when input blocked")
    end,
  })
  assertions.assert_equal(state.action_button_active, false, "input blocked should disable action button timer")
  assertions.assert_equal(state.action_button_elapsed, 0, "input blocked should reset elapsed")
end

return {
  layer = "unit",
  domain = "runtime",
  cases = {
    {
      id = "given_phase_when_check_input_blocked_then_wait_phases_true",
      desc = "phase input blocked flags",
      run = _test_phase_input_blocked_flags,
    },
    {
      id = "given_input_blocked_when_update_action_button_timer_then_reset_and_disable",
      desc = "input blocked resets action button timer",
      run = _test_action_button_timer_resets_when_input_blocked,
    },
  },
}
