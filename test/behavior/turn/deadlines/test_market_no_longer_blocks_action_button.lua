-- 验证：黑市不再屏蔽 action_button 倒计时（_has_blocking_ui 不再考虑 is_market_active）
local lu = require("luaunit")
local turn_timer_policy = require("src.turn.policies.timer")

TestMarketNoLongerBlocksActionButton = {}

function TestMarketNoLongerBlocksActionButton:test_is_action_button_wait_active_returns_true_when_market_is_active_but_no_choice_popup()
  local game = {
    finished = false,
    turn = { current_player_index = 1, pending_choice = nil },
    players = { { id = 1, auto = false } },
  }
  local state = { action_button_active = false }
  local ports = {
    ui_sync = {
      get_ui_state = function() return { ui_present = true } end,
      is_input_blocked = function() return false end,
      is_choice_active = function() return false end,
      is_market_active = function() return true end,
      is_popup_active = function() return false end,
    }
  }
  local active = turn_timer_policy.is_action_button_wait_active(game, state, ports)
  lu.assertTrue(active)
end

function TestMarketNoLongerBlocksActionButton:test_still_blocked_by_choice_active_or_popup_active()
  local game = {
    finished = false,
    turn = { current_player_index = 1, pending_choice = nil },
    players = { { id = 1, auto = false } },
  }
  local state = {}
  local ports_with_choice = {
    ui_sync = {
      get_ui_state = function() return { ui_present = true } end,
      is_input_blocked = function() return false end,
      is_choice_active = function() return true end,
      is_market_active = function() return false end,
      is_popup_active = function() return false end,
    }
  }
  lu.assertFalse(turn_timer_policy.is_action_button_wait_active(game, state, ports_with_choice))

  local ports_with_popup = {
    ui_sync = {
      get_ui_state = function() return { ui_present = true } end,
      is_input_blocked = function() return false end,
      is_choice_active = function() return false end,
      is_market_active = function() return false end,
      is_popup_active = function() return true end,
    }
  }
  lu.assertFalse(turn_timer_policy.is_action_button_wait_active(game, state, ports_with_popup))
end


return TestMarketNoLongerBlocksActionButton
