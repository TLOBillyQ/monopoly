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

  describe("multiplayer_local_role_gate", function()
    local runtime_ports = require("src.foundation.ports.runtime_ports")

    after_each(function()
      runtime_ports.reset_for_tests()
    end)

    local function _make_multi_game()
      return {
        turn = { phase = "wait_choice", current_player_index = 1 },
        players = {
          { id = 1, is_ai = false },
          { id = 2, is_ai = false },
          { id = 3, is_ai = false },
          { id = 4, is_ai = false },
        },
      }
    end

    local function _make_role(role_id)
      return { get_roleid = function() return role_id end }
    end

    local function _make_target_choice()
      return { kind = "item_target_tile", route_key = "target", owner_role_id = 1 }
    end

    it("non_turn_player_local_owner_false_when_multiple_roles", function()
      runtime_ports.configure({
        resolve_roles = function()
          return { _make_role(1), _make_role(2), _make_role(3), _make_role(4) }
        end,
      })
      local state = { ui = {} }
      local gate = choice_ui_state.resolve_gate_state(
        _make_multi_game(), state, _make_target_choice()
      )
      assert.equals(false, gate.local_owner,
        "with multiple roles and no cached local_actor_role_id, local_owner must be false")
      assert.equals(false, gate.expects_ui,
        "non-local player must not expect UI for another player's choice")
    end)

    it("current_player_id_alone_does_not_make_multiplayer_choice_local", function()
      runtime_ports.configure({
        resolve_roles = function()
          return { _make_role(1), _make_role(2), _make_role(3), _make_role(4) }
        end,
      })
      local state = { ui = {}, ui_runtime = { ui_model = { current_player_id = 1 } } }
      local gate = choice_ui_state.resolve_gate_state(
        _make_multi_game(), state, _make_target_choice()
      )
      assert.equals(false, gate.local_owner,
        "current_player_id is display state and must not authorize multiplayer choice UI")
      assert.equals(false, gate.expects_ui,
        "display-only current player must not open another client's choice UI")
    end)

    it("single_role_player_local_owner_true", function()
      runtime_ports.configure({
        resolve_roles = function()
          return { _make_role(1) }
        end,
      })
      local state = { ui = {} }
      local gate = choice_ui_state.resolve_gate_state(
        _make_multi_game(), state, _make_target_choice()
      )
      assert.equals(true, gate.local_owner,
        "with single role matching owner, local_owner must be true")
    end)
  end)
end)
