-- turn/actions 校验入口。窄入口 validate(action, ctx) → ok, reason；
-- 具名函数保留给存量调用方（dispatcher、turn/waits、契约 spec），
-- validator_actor / validator_gate / validator_item_slot 为内部实现。
local actor = require("src.turn.actions.validator_actor")
local gate = require("src.turn.actions.validator_gate")
local item_slot = require("src.turn.actions.validator_item_slot")

local validator = {}

validator.validate_actor_role = actor.validate_actor_role
validator.validate_choice_actor = actor.validate_choice_actor
validator.validate_choice_id = actor.validate_choice_id
validator.validate_choice_action = actor.validate_choice_action

validator.resolve_gate_state = gate.resolve_gate_state
validator.should_block_action = gate.should_block_action

validator.resolve_item_slot_action = item_slot.resolve_item_slot_action

local _CHOICE_BOUND_ACTION_TYPES = {
  choice_select = true,
  choice_cancel = true,
  market_page_prev = true,
  market_page_next = true,
  market_tab_select = true,
}

local function _is_item_slot_button(action)
  return action.id ~= nil and string.match(action.id, "^item_slot_%d+$") ~= nil
end

local function _validate_choice_bound(action, ctx)
  local choice = ctx.choice
  if not choice or not choice.id then
    return false, "missing_choice"
  end
  if not actor.validate_choice_actor(ctx.game, action, choice) then
    return false, "choice_actor_mismatch"
  end
  if not actor.validate_choice_id(action, choice) then
    return false, "choice_id_mismatch"
  end
  return true
end

local function _validate_ui_button(action, ctx)
  if not actor.validate_actor_role(ctx.game, action) then
    return false, "actor_not_current"
  end
  if _is_item_slot_button(action) then
    local resolution = item_slot.resolve_item_slot_resolution(ctx.item_slot_source, ctx.state, action, ctx.game)
    if not resolution.ok then
      return false, resolution.reason
    end
  end
  return true
end

-- 单入口：action + ctx → ok, reason。
-- ctx 可携带 game / state / choice / gate_state / item_slot_source。
function validator.validate(action, ctx)
  ctx = ctx or {}
  if action == nil then
    return false, "missing_action"
  end
  if ctx.gate_state ~= nil and gate.should_block_action(ctx.gate_state, action) then
    return false, "input_blocked"
  end
  if action.type == "ui_button" then
    return _validate_ui_button(action, ctx)
  end
  if _CHOICE_BOUND_ACTION_TYPES[action.type] == true then
    return _validate_choice_bound(action, ctx)
  end
  return true
end

return validator

--[[ mutate4lua-manifest
version=2
projectHash=307a3c9248d742ea
scope.0.id=chunk:src/turn/actions/validator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=fa3539d365f67759
]]
