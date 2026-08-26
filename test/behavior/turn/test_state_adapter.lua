-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):本文件是两个 spec 的合并
-- (state_adapter + state_adapter_extended,#27),原为两个 do 块各包一个 describe,
-- 钩子同为 before_each reset_all,拍平合并为单一 TestStateAdapter 类(setUp 承接);
-- 用例数与改写前一一对应(12 + 12 = 24 例)。

local output_port = require("src.turn.output.state_adapter")
local runtime_state = require("src.state.runtime")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

TestStateAdapter = {}

function TestStateAdapter:setUp()
  _config_reset.reset_all()
end

function TestStateAdapter:test_is_ui_dirty_reflects_dirty_state()
  local state = {}
  _assert_eq(output_port.is_ui_dirty(state), false, "fresh state should not be dirty")
  output_port.invalidate_ui_model(state)
  _assert_eq(output_port.is_ui_dirty(state), true, "state should be dirty after invalidate_ui_model")
end

function TestStateAdapter:test_invalidate_ui_model_returns_false_when_already_dirty()
  local state = {}
  _assert_eq(output_port.invalidate_ui_model(state), true, "first invalidate should return true")
  _assert_eq(output_port.invalidate_ui_model(state), false, "second invalidate should return false")
end

function TestStateAdapter:test_clear_ui_dirty_clears_dirty_flag_and_returns_true()
  local state = {}
  output_port.invalidate_ui_model(state)
  _assert_eq(output_port.clear_ui_dirty(state), true, "clear_ui_dirty on dirty state should return true")
  _assert_eq(runtime_state.is_ui_dirty(state), false, "after clear_ui_dirty state should be clean")
end

function TestStateAdapter:test_get_ui_model_returns_synced_model()
  local state = {}
  local model = { screen = "gameplay" }
  output_port.sync_ui_model(state, model)
  _assert_eq(output_port.get_ui_model(state), model, "get_ui_model should return synced model")
end

function TestStateAdapter:test_get_pending_choice_returns_synced_choice()
  local state = {}
  local choice = { id = 20, kind = "market_buy" }
  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 1.5 })
  _assert_eq(output_port.get_pending_choice(state), choice, "get_pending_choice should return synced choice")
end

function TestStateAdapter:test_get_pending_choice_id_returns_choice_id()
  local state = {}
  local choice = { id = 30, kind = "item_phase_passive" }
  output_port.sync_pending_choice(state, choice)
  _assert_eq(output_port.get_pending_choice_id(state), 30, "get_pending_choice_id should return choice id")
end

function TestStateAdapter:test_get_pending_choice_elapsed_returns_elapsed()
  local state = {}
  local choice = { id = 40, kind = "market_buy" }
  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 2.75 })
  _assert_eq(output_port.get_pending_choice_elapsed(state), 2.75, "get_pending_choice_elapsed should return elapsed")
end

function TestStateAdapter:test_set_pending_choice_elapsed_updates_elapsed()
  local state = {}
  output_port.set_pending_choice_elapsed(state, 3.5)
  _assert_eq(output_port.get_pending_choice_elapsed(state), 3.5, "set_pending_choice_elapsed should update elapsed")
end

function TestStateAdapter:test_set_pending_choice_id_updates_choice_id()
  local state = {}
  output_port.set_pending_choice_id(state, 99)
  _assert_eq(output_port.get_pending_choice_id(state), 99, "set_pending_choice_id should update choice id")
end

function TestStateAdapter:test_clear_pending_choice_resets_choice_fields()
  local state = {}
  local choice = { id = 50, kind = "item_phase_passive" }
  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 1.0 })
  output_port.clear_pending_choice(state)
  _assert_eq(output_port.get_pending_choice(state), nil, "after clear_pending_choice choice should be nil")
  _assert_eq(output_port.get_pending_choice_id(state), nil, "after clear_pending_choice choice id should be nil")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "after clear_pending_choice elapsed should be zero")
end

function TestStateAdapter:test_get_modal_elapsed_returns_synced_elapsed()
  local state = {}
  output_port.sync_modal_timer(state, { ref = "pop_1", elapsed_seconds = 4.0 })
  _assert_eq(output_port.get_modal_elapsed(state), 4.0, "get_modal_elapsed should return synced elapsed")
end

function TestStateAdapter:test_get_modal_ref_returns_synced_ref()
  local state = {}
  output_port.sync_modal_timer(state, { ref = "pop_2", elapsed_seconds = 0.5 })
  _assert_eq(output_port.get_modal_ref(state), "pop_2", "get_modal_ref should return synced ref")
end

-- ===== merged from test_state_adapter_extended.lua (#27) =====

function TestStateAdapter:test_get_pending_choice_on_empty_state_returns_nil()
  local state = {}
  _assert_eq(output_port.get_pending_choice(state), nil, "fresh state should have nil pending_choice")
  _assert_eq(output_port.get_pending_choice_id(state), nil, "fresh state should have nil pending_choice_id")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "fresh state should have 0 elapsed")
end

function TestStateAdapter:test_get_ui_model_on_empty_state_returns_nil()
  local state = {}
  _assert_eq(output_port.get_ui_model(state), nil, "fresh state should have nil ui_model")
end

TestStateAdapter["test_get_modal_elapsed and get_modal_ref default to 0/nil on empty state"] = function(self)
  local state = {}
  _assert_eq(output_port.get_modal_elapsed(state), 0, "fresh state modal elapsed should be 0")
  _assert_eq(output_port.get_modal_ref(state), nil, "fresh state modal ref should be nil")
end

TestStateAdapter["test_sync_pending_choice with explicit choice_id overrides choice.id"] = function(self)
  local state = {}
  local choice = { id = 10, kind = "market_buy" }
  output_port.sync_pending_choice(state, choice, { choice_id = 999, elapsed_seconds = 0 })
  _assert_eq(output_port.get_pending_choice_id(state), 999, "explicit choice_id should override")
end

function TestStateAdapter:test_sync_pending_choice_with_nil_choice_and_nil_opts_uses_defaults()
  local state = {}
  output_port.sync_pending_choice(state, nil)
  _assert_eq(output_port.get_pending_choice(state), nil, "nil choice should remain nil")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "elapsed should default to 0")
end

TestStateAdapter["test_sync_modal_timer with empty payload defaults to elapsed=0 ref=nil"] = function(self)
  local state = {}
  output_port.sync_modal_timer(state, {})
  _assert_eq(output_port.get_modal_elapsed(state), 0, "elapsed should default to 0")
  _assert_eq(output_port.get_modal_ref(state), nil, "ref should default to nil")
end

function TestStateAdapter:test_sync_modal_timer_with_nil_payload_still_works()
  local state = {}
  output_port.sync_modal_timer(state, nil)
  _assert_eq(output_port.get_modal_elapsed(state), 0, "nil payload should default elapsed to 0")
end

function TestStateAdapter:test_build_runtime_output_ports_table_functions_actually_mutate_state()
  local state = {}
  local ports = output_port.build_runtime_output_ports()
  _assert_eq(ports.invalidate_ui_model(state), true, "first invalidate_ui_model should return true")
  _assert_eq(ports.is_ui_dirty(state), true, "is_ui_dirty should be true after invalidate")
  _assert_eq(ports.clear_ui_dirty(state), true, "clear_ui_dirty should return true on dirty state")
  _assert_eq(runtime_state.is_ui_dirty(state), false, "state should be clean after clear")
end

function TestStateAdapter:test_build_runtime_output_ports_table_covers_ui_model_and_pending_choice_round_trip()
  local state = {}
  local ports = output_port.build_runtime_output_ports()
  local model = { panel = { turn_label = "P1's turn" } }
  ports.sync_ui_model(state, model)
  _assert_eq(ports.get_ui_model(state), model, "ui_model round-trip via ports should preserve model")
  local choice = { id = 77, kind = "market_buy" }
  ports.sync_pending_choice(state, choice, { elapsed_seconds = 1.0 })
  _assert_eq(ports.get_pending_choice(state), choice, "pending_choice round-trip")
  _assert_eq(ports.get_pending_choice_id(state), 77, "pending_choice_id round-trip")
  ports.set_pending_choice_id(state, 88)
  _assert_eq(ports.get_pending_choice_id(state), 88, "set_pending_choice_id via ports")
  ports.set_pending_choice_elapsed(state, 5.5)
  _assert_eq(ports.get_pending_choice_elapsed(state), 5.5, "set_pending_choice_elapsed via ports")
  ports.clear_pending_choice(state)
  _assert_eq(ports.get_pending_choice(state), nil, "clear_pending_choice via ports")
end

function TestStateAdapter:test_build_runtime_output_ports_modal_timer_accessors_work_via_ports_table()
  local state = {}
  local ports = output_port.build_runtime_output_ports()
  ports.sync_modal_timer(state, { ref = "modal_x", elapsed_seconds = 2.5 })
  _assert_eq(ports.get_modal_elapsed(state), 2.5, "modal elapsed via ports")
  _assert_eq(ports.get_modal_ref(state), "modal_x", "modal ref via ports")
end

TestStateAdapter["test_clear_ui_dirty on already-clean state returns false (idempotency)"] = function(self)
  local state = {}
  output_port.invalidate_ui_model(state)
  output_port.clear_ui_dirty(state)
  _assert_eq(output_port.clear_ui_dirty(state), false, "second clear should return false")
end

function TestStateAdapter:test_sync_pending_choice_with_nil_choice_and_explicit_choice_id_stores_choice_id()
  local state = {}
  output_port.sync_pending_choice(state, nil, { choice_id = 42, elapsed_seconds = 0.5 })
  _assert_eq(output_port.get_pending_choice(state), nil, "choice itself remains nil")
  _assert_eq(output_port.get_pending_choice_id(state), 42, "explicit choice_id stored even with nil choice")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0.5, "elapsed stored")
end


return TestStateAdapter
