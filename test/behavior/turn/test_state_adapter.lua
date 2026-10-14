local check = require("luassert")
local output_port = require("src.turn.output.state_adapter")
local runtime_state = require("src.state.runtime")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  check.equal(a, b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("TestStateAdapter", function()

before_each(function()
  _config_reset.reset_all()
end)

it("test_build_runtime_output_ports_modal_timer_accessors_work_via_ports_table", function()
  local state = {}
  local ports = output_port.build_runtime_output_ports()
  ports.sync_modal_timer(state, { ref = "modal_x", elapsed_seconds = 2.5 })
  _assert_eq(ports.get_modal_elapsed(state), 2.5, "modal elapsed via ports")
  _assert_eq(ports.get_modal_ref(state), "modal_x", "modal ref via ports")
end)

it("test_build_runtime_output_ports_table_covers_ui_model_and_pending_choice_round_trip", function()
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
end)

it("test_build_runtime_output_ports_table_functions_actually_mutate_state", function()
  local state = {}
  local ports = output_port.build_runtime_output_ports()
  _assert_eq(ports.invalidate_ui_model(state), true, "first invalidate_ui_model should return true")
  _assert_eq(ports.is_ui_dirty(state), true, "is_ui_dirty should be true after invalidate")
  _assert_eq(ports.clear_ui_dirty(state), true, "clear_ui_dirty should return true on dirty state")
  _assert_eq(runtime_state.is_ui_dirty(state), false, "state should be clean after clear")
end)

it("test_clear_pending_choice_resets_choice_fields", function()
  local state = {}
  local choice = { id = 50, kind = "item_phase_passive" }
  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 1.0 })
  output_port.clear_pending_choice(state)
  _assert_eq(output_port.get_pending_choice(state), nil, "after clear_pending_choice choice should be nil")
  _assert_eq(output_port.get_pending_choice_id(state), nil, "after clear_pending_choice choice id should be nil")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "after clear_pending_choice elapsed should be zero")
end)

it("test_clear_ui_dirty on already-clean state returns false (idempotency)", function()
  local state = {}
  output_port.invalidate_ui_model(state)
  output_port.clear_ui_dirty(state)
  _assert_eq(output_port.clear_ui_dirty(state), false, "second clear should return false")
end)

it("test_clear_ui_dirty_clears_dirty_flag_and_returns_true", function()
  local state = {}
  output_port.invalidate_ui_model(state)
  _assert_eq(output_port.clear_ui_dirty(state), true, "clear_ui_dirty on dirty state should return true")
  _assert_eq(runtime_state.is_ui_dirty(state), false, "after clear_ui_dirty state should be clean")
end)

it("test_get_modal_elapsed and get_modal_ref default to 0/nil on empty state", function()
  local state = {}
  _assert_eq(output_port.get_modal_elapsed(state), 0, "fresh state modal elapsed should be 0")
  _assert_eq(output_port.get_modal_ref(state), nil, "fresh state modal ref should be nil")
end)

it("test_get_modal_elapsed_returns_synced_elapsed", function()
  local state = {}
  output_port.sync_modal_timer(state, { ref = "pop_1", elapsed_seconds = 4.0 })
  _assert_eq(output_port.get_modal_elapsed(state), 4.0, "get_modal_elapsed should return synced elapsed")
end)

it("test_get_modal_ref_returns_synced_ref", function()
  local state = {}
  output_port.sync_modal_timer(state, { ref = "pop_2", elapsed_seconds = 0.5 })
  _assert_eq(output_port.get_modal_ref(state), "pop_2", "get_modal_ref should return synced ref")
end)

it("test_get_pending_choice_elapsed_returns_elapsed", function()
  local state = {}
  local choice = { id = 40, kind = "market_buy" }
  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 2.75 })
  _assert_eq(output_port.get_pending_choice_elapsed(state), 2.75, "get_pending_choice_elapsed should return elapsed")
end)

it("test_get_pending_choice_id_returns_choice_id", function()
  local state = {}
  local choice = { id = 30, kind = "item_phase_passive" }
  output_port.sync_pending_choice(state, choice)
  _assert_eq(output_port.get_pending_choice_id(state), 30, "get_pending_choice_id should return choice id")
end)

it("test_get_pending_choice_on_empty_state_returns_nil", function()
  local state = {}
  _assert_eq(output_port.get_pending_choice(state), nil, "fresh state should have nil pending_choice")
  _assert_eq(output_port.get_pending_choice_id(state), nil, "fresh state should have nil pending_choice_id")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "fresh state should have 0 elapsed")
end)

-- ===== merged from test_state_adapter_extended.lua (#27) =====

it("test_get_pending_choice_returns_synced_choice", function()
  local state = {}
  local choice = { id = 20, kind = "market_buy" }
  output_port.sync_pending_choice(state, choice, { elapsed_seconds = 1.5 })
  _assert_eq(output_port.get_pending_choice(state), choice, "get_pending_choice should return synced choice")
end)

it("test_get_ui_model_on_empty_state_returns_nil", function()
  local state = {}
  _assert_eq(output_port.get_ui_model(state), nil, "fresh state should have nil ui_model")
end)

it("test_get_ui_model_returns_synced_model", function()
  local state = {}
  local model = { screen = "gameplay" }
  output_port.sync_ui_model(state, model)
  _assert_eq(output_port.get_ui_model(state), model, "get_ui_model should return synced model")
end)

it("test_invalidate_ui_model_returns_false_when_already_dirty", function()
  local state = {}
  _assert_eq(output_port.invalidate_ui_model(state), true, "first invalidate should return true")
  _assert_eq(output_port.invalidate_ui_model(state), false, "second invalidate should return false")
end)

it("test_is_ui_dirty_reflects_dirty_state", function()
  local state = {}
  _assert_eq(output_port.is_ui_dirty(state), false, "fresh state should not be dirty")
  output_port.invalidate_ui_model(state)
  _assert_eq(output_port.is_ui_dirty(state), true, "state should be dirty after invalidate_ui_model")
end)

it("test_set_pending_choice_elapsed_updates_elapsed", function()
  local state = {}
  output_port.set_pending_choice_elapsed(state, 3.5)
  _assert_eq(output_port.get_pending_choice_elapsed(state), 3.5, "set_pending_choice_elapsed should update elapsed")
end)

it("test_set_pending_choice_id_updates_choice_id", function()
  local state = {}
  output_port.set_pending_choice_id(state, 99)
  _assert_eq(output_port.get_pending_choice_id(state), 99, "set_pending_choice_id should update choice id")
end)

it("test_sync_modal_timer with empty payload defaults to elapsed=0 ref=nil", function()
  local state = {}
  output_port.sync_modal_timer(state, {})
  _assert_eq(output_port.get_modal_elapsed(state), 0, "elapsed should default to 0")
  _assert_eq(output_port.get_modal_ref(state), nil, "ref should default to nil")
end)

it("test_sync_modal_timer_with_nil_payload_still_works", function()
  local state = {}
  output_port.sync_modal_timer(state, nil)
  _assert_eq(output_port.get_modal_elapsed(state), 0, "nil payload should default elapsed to 0")
end)

it("test_sync_pending_choice with explicit choice_id overrides choice.id", function()
  local state = {}
  local choice = { id = 10, kind = "market_buy" }
  output_port.sync_pending_choice(state, choice, { choice_id = 999, elapsed_seconds = 0 })
  _assert_eq(output_port.get_pending_choice_id(state), 999, "explicit choice_id should override")
end)

it("test_sync_pending_choice_with_nil_choice_and_explicit_choice_id_stores_choice_id", function()
  local state = {}
  output_port.sync_pending_choice(state, nil, { choice_id = 42, elapsed_seconds = 0.5 })
  _assert_eq(output_port.get_pending_choice(state), nil, "choice itself remains nil")
  _assert_eq(output_port.get_pending_choice_id(state), 42, "explicit choice_id stored even with nil choice")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0.5, "elapsed stored")
end)

it("test_sync_pending_choice_with_nil_choice_and_nil_opts_uses_defaults", function()
  local state = {}
  output_port.sync_pending_choice(state, nil)
  _assert_eq(output_port.get_pending_choice(state), nil, "nil choice should remain nil")
  _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "elapsed should default to 0")
end)


end)
