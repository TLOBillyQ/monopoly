local choice_support = require("src.ui.view.choice_support")
local runtime_state = require("src.ui.state.runtime")
local modal_state = require("src.ui.state.modal")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local modal_ports = require("src.ui.input.modal_ports")
local pre_confirm_gate = require("src.ui.input.pre_confirm_gate")

local pre_confirm_flow = {}

local _modal_ports = modal_ports.resolve

-- 判定段(needs_pre_confirm 与授权)已拆到 pre_confirm_gate,公共面不变。
pre_confirm_flow.needs_pre_confirm = pre_confirm_gate.needs_pre_confirm

local function _resolve_enter_params(state, intent, choice)
  local source_screen = modal_state.get_active_choice_screen_key(state)
  local option_id, option_label

  if intent.type == "choice_select" then
    option_id = intent.option_id
    option_label = choice_support.resolve_option_label_by_id(choice, option_id) or tostring(option_id)
  end

  if not option_id then
    return nil
  end
  local title = choice_support.resolve_secondary_confirm_title(choice, state.game, source_screen, option_id)
  local body = choice_support.resolve_secondary_confirm_body(choice, state.game, source_screen, option_id, option_label)
  return { source_screen = source_screen, option_id = option_id, title = title, body = body }
end

-- 参数齐了才谈开屏：宿主没挂 modal port 时静默拒绝，不留下 pending 会话。
local function _open_pre_confirm_screen(state, choice, params)
  local modal = _modal_ports(state)
  if type(modal.open_pre_confirm_screen) ~= "function" then
    return false
  end
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {
    option_id = params.option_id,
    source_screen = params.source_screen,
  })
  modal.open_pre_confirm_screen(state, choice, params.option_id, params.title, params.body)
  return true
end

local function _current_choice(state)
  local current_model = runtime_state.get_ui_model(state)
  return current_model and current_model.choice or nil
end

function pre_confirm_flow.enter(state, intent)
  local choice = _current_choice(state)
  if not choice or not choice.id then
    return false
  end
  if not pre_confirm_gate.can_actor_open(state, intent, choice) then
    return false
  end

  local params = _resolve_enter_params(state, intent, choice)
  if not params then
    return false
  end

  return _open_pre_confirm_screen(state, choice, params)
end

local function _restore_prior_screen(state, source, modal, choice)
  if source == "base_inline" or source == nil then
    if type(modal.close_choice_modal) == "function" then
      modal.close_choice_modal(state)
    end
  else
    if type(modal.open_choice_modal) == "function" then
      modal.open_choice_modal(state, choice)
    end
  end
end

function pre_confirm_flow.cancel(state)
  local record = pending_confirmation.cancel(state)
  local source = record and record.source_screen or nil
  runtime_state.set_pending_choice_id(state, nil)

  local choice = _current_choice(state)
  if not choice then return end

  _restore_prior_screen(state, source, _modal_ports(state), choice)
end

return pre_confirm_flow

--[[ mutate4lua-manifest
version=4
projectHash=17a1fa2e960aa948
scope.0.id=chunk:src/ui/input/pre_confirm.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=92
scope.0.semanticHash=039da8703f58c5e4
scope.1.id=function:_resolve_enter_params
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=30
scope.1.semanticHash=ca8a7ea0acd26d51
scope.2.id=function:_open_pre_confirm_screen
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=44
scope.2.semanticHash=06d27083e3494140
scope.3.id=function:_current_choice
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=49
scope.3.semanticHash=9225cfe7b87d962b
scope.4.id=function:pre_confirm_flow.enter
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=66
scope.4.semanticHash=ce66e5902d3c85f0
scope.5.id=function:_restore_prior_screen
scope.5.kind=function
scope.5.startLine=68
scope.5.endLine=78
scope.5.semanticHash=d3833aad2088ad1b
scope.6.id=function:pre_confirm_flow.cancel
scope.6.kind=function
scope.6.startLine=80
scope.6.endLine=89
scope.6.semanticHash=7ed01fc931be2043
]]
