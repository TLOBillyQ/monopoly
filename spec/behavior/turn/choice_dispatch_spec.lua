-- Pins for the complete_optional_action_phase handling inside
-- src/turn/actions/action_dispatcher.lua (the real optional_action_completion
-- module decides blocked/rejected; the gate resolution is stubbed per test).
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local function _build(gate_state)
  local validator_stub = {
    resolve_gate_state = function() return gate_state end,
    should_block_action = function() return false end,
    validate_actor_role = function() return true end,
    validate_choice_action = function() return true end,
    resolve_item_slot_action = function() return nil end,
  }
  -- 单入口 validate 委托 stub 自身的 validate_choice_action。
  validator_stub.validate = function(action, ctx)
    ctx = ctx or {}
    return validator_stub.validate_choice_action(ctx.game, action, ctx.choice)
  end
  local original_validator = package.loaded["src.turn.actions.validator"]
  package.loaded["src.turn.actions.validator"] = validator_stub
  local original_dispatcher = package.loaded["src.turn.actions.action_dispatcher"]
  package.loaded["src.turn.actions.action_dispatcher"] = nil
  local ok, dispatcher = pcall(require, "src.turn.actions.action_dispatcher")
  package.loaded["src.turn.actions.action_dispatcher"] = original_dispatcher
  package.loaded["src.turn.actions.validator"] = original_validator
  if not ok then
    error(dispatcher)
  end
  return dispatcher
end

local function _new_game(choice)
  return {
    turn = { pending_choice = choice },
  }
end

describe("action_dispatcher complete_optional_action_phase", function()
  it("reports blocked status when the input gate is blocked", function()
    local game = _new_game({
      id = "optional_1",
      kind = "item_phase_passive",
      allow_cancel = true,
    })
    local dispatcher = _build({ input_blocked = true })

    local result = dispatcher.dispatch_action_with_ctx(game, {}, {
      type = "complete_optional_action_phase",
      actor_role_id = 1,
    }, {}, { ui_sync_ports = {} })

    _assert_eq(result.status, "blocked", "blocked gate should report blocked status")
    _assert_eq(result.reason, "blocked", "blocked gate should carry the blocked reason")
  end)

  it("reports rejected status with the underlying reason for a non-cancelable choice", function()
    local game = _new_game({
      id = "optional_2",
      kind = "item_phase_passive",
      allow_cancel = false,
    })
    local dispatcher = _build({ input_blocked = false })

    local result = dispatcher.dispatch_action_with_ctx(game, {}, {
      type = "complete_optional_action_phase",
      actor_role_id = 1,
    }, {}, { ui_sync_ports = {} })

    _assert_eq(result.status, "rejected", "non-cancelable choice should be rejected")
    _assert_eq(result.reason, "not_cancelable_optional_action", "rejection should carry the non-cancelable reason")
  end)
end)
