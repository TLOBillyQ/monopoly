-- ui_sync/choice_state 直驱规约(#262 幸存闭合):五个输入封锁相位全集与
-- owner 解析不出时 served_owner 回落 false。
local lu = require("luaunit")
local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")

TestUiSyncChoiceState = {}

function TestUiSyncChoiceState:test_blocks_exactly_the_five_input_blocked_phases()
  -- kills _input_blocked_phases 的 true->false(既有覆盖只钉了
  -- wait_action_anim/wait_move_anim 两个相位)。
  local blocked = {
    "wait_action_anim",
    "wait_move_anim",
    "wait_landing_visual",
    "detained_wait",
    "inter_turn_wait",
  }
  for _, phase in ipairs(blocked) do
    lu.assertEquals(choice_ui_state.is_phase_input_blocked(phase), true,
      phase .. " should block input")
  end
  lu.assertEquals(choice_ui_state.is_phase_input_blocked("free"), false,
    "an unlisted phase should not block input")
  lu.assertEquals(choice_ui_state.is_phase_input_blocked(nil), false,
    "a nil phase should not block input")
end

function TestUiSyncChoiceState:test_served_owner_falls_back_to_false_when_the_owner_cannot_be_resolved()
  -- kills owner_is_served_seat 的 return false -> true:无 turn/players、choice
  -- 不带 owner 时,owner 解析不出,served_owner 必须是 false。
  local gate = choice_ui_state.resolve_gate_state({}, { ui = {} }, {})
  lu.assertEquals(gate.served_owner, false, "an unresolvable owner must not count as a served seat")
end


return TestUiSyncChoiceState
