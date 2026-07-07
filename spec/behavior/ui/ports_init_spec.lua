describe("src.ui.ports (module-level coverage)", function()
  it("loads all sub-port modules under debug hook", function()
    package.loaded["src.ui.ports.init"] = nil
    local ports = require("src.ui.ports.init")
    assert(type(ports) == "table", "expected table")
  end)

  it("ui_sync facade forwards gate and dirty refresh results", function()
    local ui_sync = require("src.ui.ports.ui_sync")
    local state = {
      ui = {
        input_blocked = false,
        popup_active = true,
        choice_active = true,
        market_active = false,
        popup_owner_index = 2,
        canvas_state = {},
      },
    }
    local common = {
      get_ui_state = function()
        return state.ui
      end,
    }
    local ports = ui_sync.build(common)

    assert.equals(false, ports.refresh_from_dirty({ turn = {} }, state, { any = false, ui = false }))
    assert.equals(false, ports.is_input_blocked(state))
    assert.equals(true, ports.is_popup_active(state))
    assert.equals(true, ports.is_choice_active(state))
    assert.equals(2, ports.get_popup_owner_index(state))
    local gate = ports.resolve_ui_gate(state)
    assert.equals(false, gate.input_blocked)
    assert.equals(true, gate.choice_active)
    assert.equals(false, gate.market_active)
    assert.equals(true, gate.popup_active)
    assert.equals(2, gate.popup_owner_index)
    assert.equals(true, ports.set_input_blocked(state, true))
    assert.equals(true, state.ui.input_blocked)
    assert.equals(false, ports.set_input_blocked(state, true))
  end)

  it("set_input_blocked returns false when ui state is nil", function()
    local ui_sync = require("src.ui.ports.ui_sync")
    local ports = ui_sync.build({ get_ui_state = function() return nil end })
    assert.equals(false, ports.set_input_blocked({}, true))
  end)

  it("resolve_choice_ui_state forwards the choice gate-state result", function()
    local ui_sync = require("src.ui.ports.ui_sync")
    local choice_state = ui_sync._choice_state
    local ports = ui_sync.build({ get_ui_state = function() return nil end })
    local game = { turn = { phase = "wait_choice", current_player_index = 1 }, players = { { id = 1 } } }
    local state = { ui = {} }
    local choice = { id = "c1", route_key = "base_inline" }
    local direct = choice_state.resolve_gate_state(game, state, choice)
    local through = ports.resolve_choice_ui_state(game, state, choice)
    assert.equals(direct, through)
    assert.is_not_nil(through)
  end)
end)
