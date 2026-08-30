-- ui_sync/choice_state 直驱规约(#262 幸存闭合):owner 解析不出时 served_owner
-- 回落 false。输入锁相位集不再是 ui 本地复制品——真源与五相位全集钉在
-- test/behavior/turn/test_loop_runtime.lua,ui 门控消费该真源的接线由
-- test_choice_state.lua 的 blocked-phase 场景钉住。
local lu = require("luaunit")
local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")

TestUiSyncChoiceState = {}

function TestUiSyncChoiceState:test_served_owner_falls_back_to_false_when_the_owner_cannot_be_resolved()
  -- kills owner_is_served_seat 的 return false -> true:无 turn/players、choice
  -- 不带 owner 时,owner 解析不出,served_owner 必须是 false。
  local gate = choice_ui_state.resolve_gate_state({}, { ui = {} }, {})
  lu.assertEquals(gate.served_owner, false, "an unresolvable owner must not count as a served seat")
end


return TestUiSyncChoiceState
