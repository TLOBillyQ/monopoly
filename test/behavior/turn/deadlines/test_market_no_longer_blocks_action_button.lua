-- 验证：黑市不再屏蔽 action_button 倒计时（_has_blocking_ui 不再考虑 is_market_active）
-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local turn_timer_policy = require("src.turn.policies.timer")

describe("TestMarketNoLongerBlocksActionButton", function()

it("test_is_action_button_wait_active_returns_true_when_market_is_active_but_no_choice_popup", function()
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
  luassert.is_true(active)
end)

it("test_still_blocked_by_choice_active_or_popup_active", function()
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
  luassert.is_false(turn_timer_policy.is_action_button_wait_active(game, state, ports_with_choice))

  local ports_with_popup = {
    ui_sync = {
      get_ui_state = function() return { ui_present = true } end,
      is_input_blocked = function() return false end,
      is_choice_active = function() return false end,
      is_market_active = function() return false end,
      is_popup_active = function() return true end,
    }
  }
  luassert.is_false(turn_timer_policy.is_action_button_wait_active(game, state, ports_with_popup))
end)


end)
