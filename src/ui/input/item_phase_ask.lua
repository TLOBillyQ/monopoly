local choice_support = require("src.ui.view.choice_support")
local runtime_state = require("src.ui.state.runtime")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local modal_ports = require("src.ui.input.modal_ports")
local highlight_lifecycle = require("src.ui.state.item_slot_highlight_lifecycle_queue")

local item_phase_ask_flow = {}

local function _close_choice_modal(state)
  modal_ports.close_choice_modal(state)
end

-- option 可以是 { id = ... } 也可以直接是裸 id。
local function _option_id(opt)
  return type(opt) == "table" and opt.id or opt
end

-- 折叠一个 option id 到累计值，返回 (累计值, 是否冲突)。
-- 冲突 = 出现了第二个与已累计值不同的 id。
local function _merge_option_id(option_id, current_id)
  if option_id == nil then
    return current_id, false
  end
  if option_id ~= current_id then
    return nil, true
  end
  return option_id, false
end

-- 所有 option 都指向同一个 id 时返回该 id，否则 nil。
local function _resolve_single_option_id(choice)
  if type(choice) ~= "table" or type(choice.options) ~= "table" then
    return nil
  end
  local option_id = nil
  for _, opt in ipairs(choice.options) do
    local conflict
    option_id, conflict = _merge_option_id(option_id, _option_id(opt))
    if conflict then
      return nil
    end
  end
  return option_id
end

local function _dispatch_single_pre_confirm_option(game, state, choice, intent, opts, action_port)
  if not choice_support.requires_item_slot_pre_confirm(choice) then
    return
  end
  local opt_id = _resolve_single_option_id(choice)
  if opt_id == nil then
    return
  end
  action_port.dispatch_action(game, state, {
    type = "choice_select",
    choice_id = choice.id,
    option_id = opt_id,
    actor_role_id = intent.actor_role_id,
  }, opts)
end

local function _handle_choice_select(state, game, intent, opts, action_port)
  pending_confirmation.confirm(state)
  local choice = runtime_state.get_ui_model_choice(state)
  -- #595:确认要带上「是哪个选择」,否则后续的迟到关闭无从匹配。
  highlight_lifecycle.push(state, "confirm_item_use", choice and choice.id or nil)
  if choice ~= nil then
    _dispatch_single_pre_confirm_option(game, state, choice, intent, opts, action_port)
  end
  _close_choice_modal(state)
  return true
end

local function _handle_choice_cancel(state, game, intent, opts, action_port)
  pending_confirmation.cancel(state)
  -- #595:关闭必须说明关的是哪个选择。旧口径只是清掉扁平旗标,刷新层遂把它
  -- 误读成槽位命令而无条件解冻——迟到的旧选择关闭会解除新选择的冻结(场景 017)。
  -- 取消/结束/替换在 ui.state 侧统一归一为 choice_released(场景 018)。
  -- 关窗前先读:_close_choice_modal 之后 ui_model 上的待决选择可能已经消失。
  local choice = runtime_state.get_ui_model_choice(state)
  highlight_lifecycle.push(state, "choice_released", choice and choice.id or nil)
  _close_choice_modal(state)
  if choice and choice.id then
    action_port.dispatch_action(game, state, {
      type = "choice_cancel",
      choice_id = choice.id,
      actor_role_id = intent.actor_role_id,
    }, opts)
  end
  return true
end

local INTENT_HANDLERS = {
  choice_select = _handle_choice_select,
  choice_cancel = _handle_choice_cancel,
}

function item_phase_ask_flow.dispatch(state, game, intent, opts, action_port)
  if not pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK) then
    return false
  end
  local handler = INTENT_HANDLERS[intent and intent.type]
  return handler and handler(state, game, intent, opts, action_port) or false
end

return item_phase_ask_flow

--[[ mutate4lua-manifest
version=4
projectHash=d8270b902cb44ecd
scope.0.id=chunk:src/ui/input/item_phase_ask.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=107
scope.0.semanticHash=dfdec4021fa102db
scope.1.id=function:_close_choice_modal
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=c772a22f8680e278
scope.2.id=function:_option_id
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=a21febbf33b567dd
scope.3.id=function:_merge_option_id
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=28
scope.3.semanticHash=4671e84a04b991d6
scope.4.id=function:_resolve_single_option_id
scope.4.kind=function
scope.4.startLine=31
scope.4.endLine=44
scope.4.semanticHash=ac2f57d4fbf1039b
scope.5.id=function:_dispatch_single_pre_confirm_option
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=60
scope.5.semanticHash=d584af9aabbed992
scope.6.id=function:_handle_choice_select
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=72
scope.6.semanticHash=c369b95d9bfe2235
scope.7.id=function:_handle_choice_cancel
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=91
scope.7.semanticHash=f782644ab5ba5456
scope.8.id=function:item_phase_ask_flow.dispatch
scope.8.kind=function
scope.8.startLine=98
scope.8.endLine=104
scope.8.semanticHash=da20ff58b7f15afd
]]
