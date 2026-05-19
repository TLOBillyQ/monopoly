local action_gate = require("src.turn.policies.action_gate")

local function _gate(overrides)
  return action_gate.resolve_gate_state(overrides or {})
end

local function _blocked(gate_state, action)
  return action_gate.should_block_action(gate_state, action)
end

describe("action_gate should_block_action", function()
  it("_test_nil_action_type_never_blocked", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, nil) == false, "nil action is always permitted")
  end)

  it("_test_popup_confirm_never_blocked", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, "popup_confirm") == false, "popup_confirm always permitted")
  end)

  it("_test_auto_button_never_blocked", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, { type = "ui_button", id = "auto" }) == false, "auto button always permitted")
  end)

  it("_test_next_button_blocked_when_choice_active", function()
    local gate = _gate({ input_blocked = false, choice_active = true })
    assert(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during choice")
  end)

  it("_test_next_button_blocked_when_market_active", function()
    local gate = _gate({ input_blocked = false, market_active = true })
    assert(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during market")
  end)

  it("_test_next_button_blocked_when_popup_active", function()
    local gate = _gate({ input_blocked = false, popup_active = true })
    assert(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during popup")
  end)

  it("_test_next_button_blocked_when_detained_active", function()
    local gate = _gate({ input_blocked = false, detained_wait_active = true })
    assert(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next blocked during detained wait")
  end)

  it("_test_next_button_blocked_via_input_blocked_types_when_no_modal", function()
    local gate = _gate({ input_blocked = true, choice_active = false, market_active = false, popup_active = false, detained_wait_active = false })
    assert(_blocked(gate, { type = "ui_button", id = "next" }) == true, "next falls through to input_blocked_types when no modal")
  end)

  it("_test_next_button_not_blocked_when_input_not_blocked_and_no_modal", function()
    local gate = _gate({ input_blocked = false })
    assert(_blocked(gate, { type = "ui_button", id = "next" }) == false, "next not blocked when input not blocked and no modal")
  end)

  it("_test_ui_button_blocked_when_input_blocked", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, { type = "ui_button", id = "other" }) == true, "ui_button blocked when input_blocked")
  end)

  it("_test_choice_pick_blocked_when_input_blocked", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, "choice_pick") == true, "choice_pick blocked when input_blocked")
  end)

  it("_test_market_confirm_blocked_when_input_blocked", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, "market_confirm") == true, "market_confirm blocked when input_blocked")
  end)

  it("_test_not_blocked_when_input_not_blocked", function()
    local gate = _gate({ input_blocked = false })
    assert(_blocked(gate, "choice_pick") == false, "choice_pick not blocked when input not blocked")
  end)

  it("_test_string_action_same_as_table_action", function()
    local gate = _gate({ input_blocked = true })
    assert(_blocked(gate, "ui_button") == true, "string ui_button also blocked")
  end)

  it("_test_resolve_gate_state_from_boolean_flag", function()
    local gate = action_gate.resolve_gate_state(true)
    assert(gate.input_blocked == true, "true flag sets input_blocked")
    assert(gate.choice_active == false, "choice_active defaults false")
    local gate_false = action_gate.resolve_gate_state(false)
    assert(gate_false.input_blocked == false, "false flag clears input_blocked")
  end)
end)
