local support = require("spec.support.presentation_support")

local validator = require("src.turn.actions.validator")
local tick_timeout = require("src.turn.waits.timeout")
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")
local canvas_store = require("src.ui.stores.canvas_store")

describe("ui_gate_contract", function()
  it("ui_gate_resolve_state_uses_port_contract", function()
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
    assert.equals(true, gate_state.input_blocked, "input_blocked should come from resolve_ui_gate contract")
    assert.equals(true, gate_state.choice_active, "choice_active should come from resolve_ui_gate contract")
    assert.equals(false, gate_state.market_active, "market_active should come from resolve_ui_gate contract")
    assert.equals(true, gate_state.popup_active, "popup_active should come from resolve_ui_gate contract")
    assert.equals("wait_action_anim", gate_state.phase, "phase should still come from game turn")
    assert.equals(true, gate_state.detained_wait_active, "detained_wait_active should still come from game turn")
  end)

  it("ui_gate_modal_timeout_prefers_gate_payload", function()
    local seconds = tick_timeout.resolve_modal_timeout_seconds(nil, {}, {
      resolve_ui_gate = function()
        return {
          popup_auto_close_seconds = 3.25,
        }
      end,
    })
    assert.equals(3.25, seconds, "modal timeout should prefer resolve_ui_gate popup_auto_close_seconds")
  end)

  it("ui_gate_set_input_blocked_marks_base_dirty_only", function()
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

    assert.equals(true, changed, "set_input_blocked should report changed when value flips")
    assert.equals(true, state.ui.input_blocked, "set_input_blocked should write ui gate state")
    assert.equals(true, dirty.base, "set_input_blocked should mark base render dirty")
    assert.equals(nil, state.ui_runtime, "set_input_blocked should not allocate ui_runtime or mark ui_model dirty")
  end)
end)
