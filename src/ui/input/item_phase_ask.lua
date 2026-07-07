local choice_support = require("src.ui.view.choice_support")
local runtime_state = require("src.ui.state.runtime")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local modal_ports = require("src.ui.input.modal_ports")

local item_phase_ask_flow = {}

local _modal_ports = modal_ports.resolve

local function _current_choice(state)
  local current_model = runtime_state.get_ui_model(state)
  return current_model and current_model.choice or nil
end

local function _close_choice_modal(state)
  local modal = _modal_ports(state)
  if type(modal.close_choice_modal) == "function" then
    modal.close_choice_modal(state)
  end
end

local function _resolve_single_option_id(choice)
  if type(choice) ~= "table" or type(choice.options) ~= "table" then
    return nil
  end
  local option_id = nil
  for _, opt in ipairs(choice.options) do
    local current_id = type(opt) == "table" and opt.id or opt
    if current_id ~= nil then
      if option_id == nil then
        option_id = current_id
      elseif option_id ~= current_id then
        return nil
      end
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
  state._suppress_item_slot_highlight_until_pick = nil
  local choice = _current_choice(state)
  state._skip_item_slot_highlight_replay_choice_id = choice and choice.id or nil
  if choice ~= nil then
    _dispatch_single_pre_confirm_option(game, state, choice, intent, opts, action_port)
  end
  _close_choice_modal(state)
  return true
end

local function _handle_choice_cancel(state, game, intent, opts, action_port)
  pending_confirmation.cancel(state)
  state._suppress_item_slot_highlight_until_pick = nil
  state._skip_item_slot_highlight_replay_choice_id = nil
  _close_choice_modal(state)
  local choice = _current_choice(state)
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
version=2
projectHash=44770739b5687995
scope.0.id=chunk:src/ui/input/item_phase_ask.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=99
scope.0.semanticHash=af41a11a941d1add
scope.1.id=function:_current_choice:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=12
scope.1.semanticHash=fb9d72b984b0d4e2
scope.2.id=function:_close_choice_modal:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=19
scope.2.semanticHash=32d4f17bf16020a3
scope.3.id=function:_dispatch_single_pre_confirm_option:39
scope.3.kind=function
scope.3.startLine=39
scope.3.endLine=53
scope.3.semanticHash=4503e19f370bb79f
scope.4.id=function:_handle_choice_select:55
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=66
scope.4.semanticHash=9a62bdf7d836c2f0
scope.5.id=function:_handle_choice_cancel:68
scope.5.kind=function
scope.5.startLine=68
scope.5.endLine=83
scope.5.semanticHash=c5e531061feb859e
scope.6.id=function:item_phase_ask_flow.dispatch:90
scope.6.kind=function
scope.6.startLine=90
scope.6.endLine=96
scope.6.semanticHash=9f78b095b9131715
]]
