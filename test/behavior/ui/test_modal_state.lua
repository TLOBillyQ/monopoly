--- 原生 LuaUnit 迁移(busted → luaunit):describe 拍平为文件级 Test* 类,
--- 断言词汇切到 lu.assertXxx,用例数与改写前一一对应(5 例)。

local support = require("test.support.shared_support")
local modal_state = require("src.ui.state.modal")

local _assert_eq = support.assert_eq

TestModalState = {}

function TestModalState:test_operator_role_id_prefers_current_action_role()
  local state = {
    ui = { current_action_role_id = 2 },
    ui_model = { current_player_id = 1 },
  }
  _assert_eq(modal_state.operator_role_id(state), 2, "acting role should win over model fallback")
end

function TestModalState:test_operator_role_id_falls_back_to_model_current_player()
  -- 行动 role 为空(如电脑玩家回合)时,回退到模型侧当前玩家。
  local runtime_state = require("src.ui.state.runtime")
  local state = { ui = {} }
  runtime_state.set_ui_model(state, { current_player_id = "3" })
  _assert_eq(modal_state.operator_role_id(state), 3, "fallback should normalize model current player id")
end

function TestModalState:test_operator_role_id_returns_nil_without_ui_or_model()
  _assert_eq(modal_state.operator_role_id(nil), nil, "nil state should resolve to nil operator")
  _assert_eq(modal_state.operator_role_id({ ui = {} }), nil, "missing model should resolve to nil operator")
end

function TestModalState:test_open_popup_increments_popup_seq()
  local state = { ui = {} }
  modal_state.open_popup(state, { title = "A" })
  _assert_eq(state.ui.popup_seq, 1, "first open should stamp seq 1")
  modal_state.close_popup(state)
  modal_state.open_popup(state, { title = "B" })
  _assert_eq(state.ui.popup_seq, 2, "second open should stamp seq 2")
end

function TestModalState:test_get_active_choice_screen_key_reads_ui_state()
  _assert_eq(modal_state.get_active_choice_screen_key({ ui = { active_choice_screen_key = "market" } }),
    "market", "should read active choice screen key from ui state")
  _assert_eq(modal_state.get_active_choice_screen_key({}), nil, "missing ui should resolve to nil")
  _assert_eq(modal_state.get_active_choice_screen_key(nil), nil, "nil state should resolve to nil")
end


return TestModalState
