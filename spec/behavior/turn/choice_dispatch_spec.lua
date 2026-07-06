local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local choice_dispatch = require("src.turn.actions.choice_dispatch")

local function _new_game(choice)
  return {
    turn = { pending_choice = choice },
  }
end

describe("choice_dispatch.handle_optional_action_completion", function()
  it("reports blocked status when the input gate is blocked", function()
    local game = _new_game({
      id = "optional_1",
      kind = "item_phase_passive",
      allow_cancel = true,
    })
    local validator = {
      resolve_gate_state = function() return { input_blocked = true } end,
    }
    local ctx = { ui_sync_ports = {} }

    local result = choice_dispatch.handle_optional_action_completion(
      game, {}, { actor_role_id = 1 }, {}, ctx, validator, function() end
    )

    _assert_eq(result.status, "blocked", "blocked gate should report blocked status")
    _assert_eq(result.reason, "blocked", "blocked gate should carry the blocked reason")
  end)

  it("reports rejected status with the underlying reason for a non-cancelable choice", function()
    local game = _new_game({
      id = "optional_2",
      kind = "item_phase_passive",
      allow_cancel = false,
    })
    local validator = {
      resolve_gate_state = function() return { input_blocked = false } end,
    }
    local ctx = { ui_sync_ports = {} }

    local result = choice_dispatch.handle_optional_action_completion(
      game, {}, { actor_role_id = 1 }, {}, ctx, validator, function() end
    )

    _assert_eq(result.status, "rejected", "non-cancelable choice should be rejected")
    _assert_eq(result.reason, "not_cancelable_optional_action", "rejection should carry the non-cancelable reason")
  end)
end)
