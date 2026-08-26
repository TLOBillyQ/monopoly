local logger = require("src.foundation.log")

local turn_action_port = {}

local _default_turn_action_port = {
  dispatch_action = function()
    return { status = "rejected" }
  end,
  should_block_action = function()
    return false
  end,
}

local function _state_port(state)
  return state and state.turn_action_port or nil
end

local function _resolve_raw_port(state, opts)
  local override_port = opts and opts.turn_action_port or nil
  return override_port or _state_port(state)
end

local function _resolve_port_method(raw, method_name)
  if type(raw) == "table" and type(raw[method_name]) == "function" then
    return raw[method_name]
  end
  return _default_turn_action_port[method_name]
end

function turn_action_port.resolve(state, opts)
  local raw = _resolve_raw_port(state, opts)
  if type(raw) ~= "table" then
    return _default_turn_action_port
  end
  return {
    dispatch_action = _resolve_port_method(raw, "dispatch_action"),
    should_block_action = _resolve_port_method(raw, "should_block_action"),
  }
end

function turn_action_port.should_block(state, intent, action_port)
  return action_port.should_block_action(state, intent)
end

-- 行动者归属在事件边界(canvas_event_router 的 attach_event_actor)裁定一次,
-- 用例层只消费不再解析(ADR 0054,CONTEXT.md「行动者」)。auto 按钮经
-- event_actor_policy.attach_event_actor 后才到这里,actor_role_id 保证非 nil;
-- nil 兜底拒绝是挡测试误用的 guard,生产路径不可达(#442 复核结论)。
function turn_action_port.normalize_auto_intent(state, intent)
  local action = {}
  for k, v in pairs(intent) do
    action[k] = v
  end
  if action.actor_role_id == nil then
    logger.warn("auto intent missing actor_role_id")
    return nil
  end
  return action
end

return turn_action_port

--[[ mutate4lua-manifest
version=4
projectHash=f4c3bbe20b830e0c
scope.0.id=chunk:src/ui/input/turn_action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=62
scope.0.semanticHash=8a6c5c2d245ef091
scope.1.id=function:<anonymous>
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=d85e0d1244ba474f
scope.2.id=function:<anonymous>#2
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=22b57f529f3a8828
scope.3.id=function:_state_port
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_resolve_raw_port
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=21
scope.4.semanticHash=525a024b6afee1bf
scope.5.id=function:_resolve_port_method
scope.5.kind=function
scope.5.startLine=23
scope.5.endLine=28
scope.5.semanticHash=b987610eb4473505
scope.6.id=function:turn_action_port.resolve
scope.6.kind=function
scope.6.startLine=30
scope.6.endLine=39
scope.6.semanticHash=aee0cecadc7e1d61
scope.7.id=function:turn_action_port.should_block
scope.7.kind=function
scope.7.startLine=41
scope.7.endLine=43
scope.7.semanticHash=3c26bf1ea8e4b724
scope.8.id=function:turn_action_port.normalize_auto_intent
scope.8.kind=function
scope.8.startLine=49
scope.8.endLine=59
scope.8.semanticHash=dc8b421ed6b9de71
]]
