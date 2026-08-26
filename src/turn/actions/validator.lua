-- turn/actions 校验入口。窄入口 validate(action, ctx) → ok, reason，
-- 派发器的 choice 类校验统一走 validate（内部委托 validate_choice_action，
-- 不重写组合）；具名函数保留给 gate 与存量调用方（turn/waits、契约 spec），
-- validator_actor / validator_gate 为内部实现。
-- 道具槽点击不在本模块校验：它的裁定（含拒绝反馈）独占在
-- src.turn.actions.item_slot_click，校验与反馈分家正是老设计的夹缝来源。
local actor = require("src.turn.actions.validator_actor")
local actor_choice = require("src.turn.actions.validator_actor_choice")
local gate = require("src.turn.actions.validator_gate")

local validator = {}

validator.validate_actor_role = actor.validate_actor_role
validator.validate_choice_actor = actor_choice.validate_choice_actor
validator.validate_choice_id = actor_choice.validate_choice_id
validator.validate_choice_action = actor_choice.validate_choice_action

validator.resolve_gate_state = gate.resolve_gate_state
validator.should_block_action = gate.should_block_action

local _CHOICE_BOUND_ACTION_TYPES = {
  choice_select = true,
  choice_cancel = true,
  market_page_prev = true,
  market_page_next = true,
  market_tab_select = true,
}

local function _validate_ui_button(action, ctx)
  if not actor.validate_actor_role(ctx.game, action) then
    return false, "actor_not_current"
  end
  return true
end

-- 派发前的拒绝闸：返回 reason 表示 action 未进入类型派发即被拒。
local function _reject_reason(action, ctx)
  if action == nil then
    return "missing_action"
  end
  if ctx.gate_state ~= nil and gate.should_block_action(ctx.gate_state, action) then
    return "input_blocked"
  end
  return nil
end

-- 单入口：action + ctx → ok, reason。
-- ctx 可携带 game / state / choice / gate_state。
function validator.validate(action, ctx)
  ctx = ctx or {}
  local reason = _reject_reason(action, ctx)
  if reason then
    return false, reason
  end
  if action.type == "ui_button" then
    return _validate_ui_button(action, ctx)
  end
  if _CHOICE_BOUND_ACTION_TYPES[action.type] == true then
    -- 复用组合校验单点，不在此处重写组合逻辑。
    return actor_choice.validate_choice_action(ctx.game, action, ctx.choice)
  end
  return true
end

return validator

--[[ mutate4lua-manifest
version=4
projectHash=26c0adb47180b013
scope.0.id=chunk:src/turn/actions/validator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=66
scope.0.semanticHash=89cdf5c80abba95b
scope.1.id=function:_validate_ui_button
scope.1.kind=function
scope.1.startLine=29
scope.1.endLine=34
scope.1.semanticHash=c2fe23d4945d2fca
scope.2.id=function:_reject_reason
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=45
scope.2.semanticHash=e9d04f66868114b0
scope.3.id=function:validator.validate
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=63
scope.3.semanticHash=ca5cb735e5ae78de
]]
