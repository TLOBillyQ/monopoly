local support = require("support.presentation_support")
local _assert_eq = support.assert_eq

local validator = require("src.turn.actions.validator")
local tick_timeout = require("src.turn.waits.timeout")
local ui_gate_sync = require("src.presentation.runtime.ports.ui_sync.gate")
local canvas_store = require("src.ui.stores.canvas_store")

local function _test_ui_gate_resolve_state_uses_port_contract()
  local state = {
    game = {
      turn = {
        phase = "wait_action_anim",
        detained_wait_active = true,
      },
    },
  }
  local ui_sync_ports = {
    resolve_ui_gate = function()
      return {
        input_blocked = true,
        choice_active = true,
        market_active = false,
        popup_active = true,
      }
    end,
    get_ui_state = function()
      error("resolve_gate_state should not read ui state directly when resolve_ui_gate exists")
    end,
  }

  local gate_state = validator.resolve_gate_state(state, ui_sync_ports)
  _assert_eq(gate_state.input_blocked, true, "input_blocked should come from resolve_ui_gate contract")
  _assert_eq(gate_state.choice_active, true, "choice_active should come from resolve_ui_gate contract")
  _assert_eq(gate_state.market_active, false, "market_active should come from resolve_ui_gate contract")
  _assert_eq(gate_state.popup_active, true, "popup_active should come from resolve_ui_gate contract")
  _assert_eq(gate_state.phase, "wait_action_anim", "phase should still come from game turn")
  _assert_eq(gate_state.detained_wait_active, true, "detained_wait_active should still come from game turn")
end

local function _test_ui_gate_modal_timeout_prefers_gate_payload()
  local seconds = tick_timeout.resolve_modal_timeout_seconds(nil, {}, {
    resolve_ui_gate = function()
      return {
        popup_auto_close_seconds = 3.25,
      }
    end,
  })
  _assert_eq(seconds, 3.25, "modal timeout should prefer resolve_ui_gate popup_auto_close_seconds")
end

local function _test_ui_gate_set_input_blocked_marks_base_dirty_only()
  local state = {
    ui = {
      input_blocked = false,
      canvas_state = {},
    },
  }
  local common = {
    get_ui_state = function()
      return state.ui
    end,
  }

  local changed = ui_gate_sync.set_input_blocked(state, true, common)
  local dirty = canvas_store.consume_dirty(state)

  _assert_eq(changed, true, "set_input_blocked should report changed when value flips")
  _assert_eq(state.ui.input_blocked, true, "set_input_blocked should write ui gate state")
  _assert_eq(dirty.base, true, "set_input_blocked should mark base render dirty")
  _assert_eq(state.ui_runtime, nil, "set_input_blocked should not allocate ui_runtime or mark ui_model dirty")
end

return {
  name = "ui_gate_contract",
  tests = {
    { name = "ui_gate_resolve_state_uses_port_contract", run = _test_ui_gate_resolve_state_uses_port_contract },
    { name = "ui_gate_modal_timeout_prefers_gate_payload", run = _test_ui_gate_modal_timeout_prefers_gate_payload },
    { name = "ui_gate_set_input_blocked_marks_base_dirty_only", run = _test_ui_gate_set_input_blocked_marks_base_dirty_only },
  },
}
