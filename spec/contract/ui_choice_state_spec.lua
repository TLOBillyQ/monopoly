local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")

-- item_phase_passive is an inline choice (no choice modal opened). The gate state
-- must treat it as open=true so that should_warn and should_reconcile stay false
-- even when the local player is the active owner and the phase is not blocked.
describe("ui_choice_state_contract", function()
  local function _make_game()
    return {
      turn = { phase = "item_phase", current_player_index = 1 },
      players = { { id = 1, is_ai = false } },
    }
  end

  local function _make_state()
    -- local_actor_role_id drives _is_local_role → local_owner = true
    return { ui = {}, ui_runtime = { local_actor_role_id = 1 } }
  end

  local function _make_choice()
    return { kind = "item_phase_passive", route_key = "item_phase_passive", owner_role_id = 1 }
  end

  it("item_phase_passive_gate_should_warn_false", function()
    local gate = choice_ui_state.resolve_gate_state(_make_game(), _make_state(), _make_choice())
    assert.equals(true, gate.local_owner, "test precondition: local_owner must be true to exercise the warn path")
    assert.equals(true, gate.expects_ui, "test precondition: expects_ui must be true so open drives should_warn")
    assert.equals(false, gate.should_warn, "item_phase_passive inline choice must not trigger a pending-UI warn")
  end)

  it("item_phase_passive_should_reconcile_false", function()
    local result = choice_ui_state.should_reconcile(_make_game(), _make_state(), _make_choice())
    assert.equals(false, result, "item_phase_passive inline choice must not trigger modal reconcile")
  end)
end)
