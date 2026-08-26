local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local choice_ports = require("src.turn.deadlines.choice_ports")
local state_adapter = require("src.turn.output.state_adapter")

TestChoicePorts = {}

-- is_action_dispatchable 覆盖（杀掉 complete_optional_action_phase→nil 幸存者）

function TestChoicePorts:test_is_action_dispatchable_choice_select()
  _assert_eq(choice_ports.is_action_dispatchable({ type = "choice_select" }), true,
    "choice_select should be dispatchable")
end

function TestChoicePorts:test_is_action_dispatchable_choice_cancel()
  _assert_eq(choice_ports.is_action_dispatchable({ type = "choice_cancel" }), true,
    "choice_cancel should be dispatchable")
end

function TestChoicePorts:test_is_action_dispatchable_complete_optional_action_phase()
  _assert_eq(choice_ports.is_action_dispatchable({ type = "complete_optional_action_phase" }), true,
    "complete_optional_action_phase should be dispatchable")
end

function TestChoicePorts:test_is_action_dispatchable_non_table()
  _assert_eq(choice_ports.is_action_dispatchable(nil), false,
    "nil action should not be dispatchable")
  _assert_eq(choice_ports.is_action_dispatchable("not-a-table"), false,
    "non-table action should not be dispatchable")
end

function TestChoicePorts:test_is_action_dispatchable_unknown_type()
  _assert_eq(choice_ports.is_action_dispatchable({ type = "unknown" }), false,
    "unknown action type should not be dispatchable")
end

-- dispatch_via_close_choice 覆盖（杀掉 _dispatch_to_game / _clear_game_pending_choice
-- 的 and→or 幸存者：nil game 下 or 会对 game.dispatch_action / game.turn 越界报错；
-- 以及 resolve_output_ports 的 require→nil 幸存者：空 state 回落 output adapter）

function TestChoicePorts:test_dispatch_via_close_choice_with_nil_game_does_not_error()
  -- 原码：nil game 全跳过，测试静默完成即断言；and→or 突变会对
  -- game.dispatch_action / game.turn 越界报错使本测试失败
  choice_ports.dispatch_via_close_choice(nil, {}, { type = "choice_cancel", choice_id = "c1" })
end

function TestChoicePorts:test_dispatch_via_close_choice_clears_output_choice_via_adapter_fallback()
  local cleared = 0
  _with_patches({
    { target = state_adapter, key = "clear_pending_choice",
      value = function() cleared = cleared + 1 end },
  }, function()
    choice_ports.dispatch_via_close_choice({}, {}, { type = "choice_cancel", choice_id = "c1" })
  end)
  _assert_eq(cleared, 1, "empty state should fall back to the output adapter and clear pending choice")
end

return TestChoicePorts
