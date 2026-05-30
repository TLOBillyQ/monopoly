-- 验证：黑市不再屏蔽 action_button 倒计时（_has_blocking_ui 不再考虑 is_market_active）
local turn_timer_policy = require("src.turn.policies.timer")

describe("market no longer blocks action button", function()
  it("is_action_button_wait_active returns true when market is active but no choice/popup", function()
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
    assert.is_true(active)
  end)

  it("still blocked by choice_active or popup_active", function()
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
    assert.is_false(turn_timer_policy.is_action_button_wait_active(game, state, ports_with_choice))

    local ports_with_popup = {
      ui_sync = {
        get_ui_state = function() return { ui_present = true } end,
        is_input_blocked = function() return false end,
        is_choice_active = function() return false end,
        is_market_active = function() return false end,
        is_popup_active = function() return true end,
      }
    }
    assert.is_false(turn_timer_policy.is_action_button_wait_active(game, state, ports_with_popup))
  end)
end)
