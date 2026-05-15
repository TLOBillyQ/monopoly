local output_port = require("src.turn.output.state_adapter")
local runtime_state = require("src.state.runtime")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("domain state adapter extended coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("get_pending_choice on empty state returns nil", function()
    local state = {}
    _assert_eq(output_port.get_pending_choice(state), nil, "fresh state should have nil pending_choice")
    _assert_eq(output_port.get_pending_choice_id(state), nil, "fresh state should have nil pending_choice_id")
    _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "fresh state should have 0 elapsed")
  end)

  it("get_ui_model on empty state returns nil", function()
    local state = {}
    _assert_eq(output_port.get_ui_model(state), nil, "fresh state should have nil ui_model")
  end)

  it("get_modal_elapsed and get_modal_ref default to 0/nil on empty state", function()
    local state = {}
    _assert_eq(output_port.get_modal_elapsed(state), 0, "fresh state modal elapsed should be 0")
    _assert_eq(output_port.get_modal_ref(state), nil, "fresh state modal ref should be nil")
  end)

  it("sync_pending_choice with explicit choice_id overrides choice.id", function()
    local state = {}
    local choice = { id = 10, kind = "market_buy" }
    output_port.sync_pending_choice(state, choice, { choice_id = 999, elapsed_seconds = 0 })
    _assert_eq(output_port.get_pending_choice_id(state), 999, "explicit choice_id should override")
  end)

  it("sync_pending_choice with nil choice and nil opts uses defaults", function()
    local state = {}
    output_port.sync_pending_choice(state, nil)
    _assert_eq(output_port.get_pending_choice(state), nil, "nil choice should remain nil")
    _assert_eq(output_port.get_pending_choice_elapsed(state), 0, "elapsed should default to 0")
  end)

  it("sync_modal_timer with empty payload defaults to elapsed=0 ref=nil", function()
    local state = {}
    output_port.sync_modal_timer(state, {})
    _assert_eq(output_port.get_modal_elapsed(state), 0, "elapsed should default to 0")
    _assert_eq(output_port.get_modal_ref(state), nil, "ref should default to nil")
  end)

  it("sync_modal_timer with nil payload still works", function()
    local state = {}
    output_port.sync_modal_timer(state, nil)
    _assert_eq(output_port.get_modal_elapsed(state), 0, "nil payload should default elapsed to 0")
  end)

  it("build_runtime_output_ports table functions actually mutate state", function()
    local state = {}
    local ports = output_port.build_runtime_output_ports()
    _assert_eq(ports.invalidate_ui_model(state), true, "first invalidate_ui_model should return true")
    _assert_eq(ports.is_ui_dirty(state), true, "is_ui_dirty should be true after invalidate")
    _assert_eq(ports.clear_ui_dirty(state), true, "clear_ui_dirty should return true on dirty state")
    _assert_eq(runtime_state.is_ui_dirty(state), false, "state should be clean after clear")
  end)

  it("build_runtime_output_ports table covers ui_model and pending_choice round-trip", function()
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

  it("build_runtime_output_ports modal_timer accessors work via ports table", function()
    local state = {}
    local ports = output_port.build_runtime_output_ports()
    ports.sync_modal_timer(state, { ref = "modal_x", elapsed_seconds = 2.5 })
    _assert_eq(ports.get_modal_elapsed(state), 2.5, "modal elapsed via ports")
    _assert_eq(ports.get_modal_ref(state), "modal_x", "modal ref via ports")
  end)

  it("clear_ui_dirty on already-clean state returns false (idempotency)", function()
    local state = {}
    output_port.invalidate_ui_model(state)
    output_port.clear_ui_dirty(state)
    _assert_eq(output_port.clear_ui_dirty(state), false, "second clear should return false")
  end)

  it("sync_pending_choice with nil choice and explicit choice_id stores choice_id", function()
    local state = {}
    output_port.sync_pending_choice(state, nil, { choice_id = 42, elapsed_seconds = 0.5 })
    _assert_eq(output_port.get_pending_choice(state), nil, "choice itself remains nil")
    _assert_eq(output_port.get_pending_choice_id(state), 42, "explicit choice_id stored even with nil choice")
    _assert_eq(output_port.get_pending_choice_elapsed(state), 0.5, "elapsed stored")
  end)
end)
