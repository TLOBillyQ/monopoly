local runtime = require("turn.runtime")
local constants = require("cfg.Generated.Constants")
local assertions = require("support.assertions")

local function _build_ports()
  return {
    ui_sync = {
      get_ui_state = function(state)
        return state and state.ui or nil
      end,
      is_input_blocked = function(state)
        local ui = state and state.ui or nil
        return ui and ui.input_blocked == true or false
      end,
      is_popup_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.popup_active == true or false
      end,
      is_choice_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.choice_active == true or false
      end,
      is_market_active = function(state)
        local ui = state and state.ui or nil
        return ui and ui.market_active == true or false
      end,
    },
  }
end

local function _build_game_state()
  local state = {
    ui = {
      input_blocked = false,
      popup_active = false,
      choice_active = false,
      market_active = false,
    },
    action_button_active = false,
    action_button_elapsed = 0,
  }
  local game = {
    finished = false,
    turn = {
      pending_choice = nil,
      current_player_index = 1,
    },
    players = {
      [1] = { id = 1 },
    },
  }
  return game, state
end

local function _test_popup_blocks_action_button_timer()
  local game, state = _build_game_state()
  state.ui.popup_active = true

  runtime.update_action_button_timer({
    game = game,
    state = state,
    dt = (constants.action_timeout_seconds or 1) + 0.2,
    ports = _build_ports(),
    dispatch_next = function()
      error("dispatch_next should be blocked when popup is active")
    end,
  })

  assertions.assert_equal(state.action_button_active, false, "popup should disable action button timer")
  assertions.assert_equal(state.action_button_elapsed, 0, "popup should reset action button timer")
end

local function _test_action_button_recovers_after_popup_cleared()
  local game, state = _build_game_state()
  local dispatch_count = 0
  state.ui.popup_active = true

  runtime.update_action_button_timer({
    game = game,
    state = state,
    dt = 0.3,
    ports = _build_ports(),
    dispatch_next = function()
      dispatch_count = dispatch_count + 1
    end,
  })

  state.ui.popup_active = false
  runtime.update_action_button_timer({
    game = game,
    state = state,
    dt = (constants.action_timeout_seconds or 1) + 0.2,
    ports = _build_ports(),
    dispatch_next = function()
      dispatch_count = dispatch_count + 1
    end,
  })

  assertions.assert_equal(dispatch_count, 1, "action button timeout should dispatch once after popup cleared")
  assertions.assert_equal(state.action_button_elapsed, 0, "elapsed should reset after dispatch")
end

return {
  layer = "unit",
  domain = "action_button_timer",
  cases = {
    {
      id = "given_popup_active_when_update_action_button_timer_then_block_and_reset",
      desc = "popup blocks action button timer",
      run = _test_popup_blocks_action_button_timer,
    },
    {
      id = "given_popup_cleared_when_update_action_button_timer_then_resume_and_dispatch",
      desc = "action button timer recovers after popup cleared",
      run = _test_action_button_recovers_after_popup_cleared,
    },
  },
}
