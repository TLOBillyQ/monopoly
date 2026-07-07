local logger = require("src.foundation.log")
local runtime_state = require("src.ui.state.runtime")
local modal_state = require("src.ui.state.modal")

local intents = {}

local function _resolve_option_id_from_payload(payload)
  return payload.option_id or payload.option or nil
end

local function _resolve_index_from_payload(payload)
  return payload.index or payload.option_index or payload.card_index or payload.choice_index
end

local function _resolve_mapped_from_runtime(state, index)
  if state == nil then
    return nil
  end
  return modal_state.get_visible_option_id(state, index)
end

local function _resolve_option_by_index(choice, index)
  local options = choice.options
  if type(options) ~= "table" then
    return nil
  end
  local option = options[index]
  if option then
    return option.id or option
  end
  return nil
end

function intents.resolve_option_id(choice, payload, state)
  assert(choice ~= nil, "missing choice")
  assert(payload ~= nil, "missing payload")
  local option_id = _resolve_option_id_from_payload(payload)
  if option_id then
    return option_id
  end
  local index = _resolve_index_from_payload(payload)
  if index then
    local mapped = _resolve_mapped_from_runtime(state, index)
    if mapped then
      return mapped
    end
    return _resolve_option_by_index(choice, index)
  end
  return nil
end

local function _resolve_choice_or_warn(state, warn_label)
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
  end
  return choice
end

function intents.choice_cancel_intent(state, warn_label)
  local choice = _resolve_choice_or_warn(state, warn_label)
  if not choice then
    return nil
  end
  if choice.allow_cancel == false then
    return nil
  end
  return { type = "choice_cancel", choice_id = choice.id }
end

function intents.choice_select_intent(state, index, warn_label)
  local choice = _resolve_choice_or_warn(state, warn_label)
  if not choice then
    return nil
  end
  local option_id = intents.resolve_option_id(choice, { index = index }, state)
  if not option_id then
    logger.warn(warn_label .. " missing option:", tostring(index))
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
end

function intents.choice_confirm_intent(state, warn_label)
  local choice = _resolve_choice_or_warn(state, warn_label)
  if not choice then
    return nil
  end
  local option_id = modal_state.get_selected_option_id(state)
  if option_id == nil then
    option_id = modal_state.get_visible_option_id(state, 1)
  end
  if option_id == nil then
    logger.warn(warn_label .. " missing selected option")
    return nil
  end
  return {
    type = "choice_select",
    choice_id = choice.id,
    option_id = option_id,
  }
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=1ee48a6232c74cde
scope.0.id=chunk:src/ui/input/event_intents.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=108
scope.0.semanticHash=f9d62b88642d73b8
scope.1.id=function:_resolve_option_id_from_payload:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=2f38ecde3daf368b
scope.2.id=function:_resolve_index_from_payload:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=55ded17321e0530f
scope.3.id=function:_resolve_mapped_from_runtime:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=17
scope.3.semanticHash=6ae61a808904051b
scope.4.id=function:_resolve_option_by_index:19
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=29
scope.4.semanticHash=36050bc01b67d2d3
scope.5.id=function:intents.resolve_option_id:31
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=47
scope.5.semanticHash=22ecf4110e2425a2
scope.6.id=function:_resolve_choice_or_warn:49
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=56
scope.6.semanticHash=b054bf7aa3308543
scope.7.id=function:intents.choice_cancel_intent:58
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=67
scope.7.semanticHash=503ad175221b7864
scope.8.id=function:intents.choice_select_intent:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=84
scope.8.semanticHash=11908dcb15239d65
scope.9.id=function:intents.choice_confirm_intent:86
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=105
scope.9.semanticHash=5eb8ef008c0dfe35
]]
