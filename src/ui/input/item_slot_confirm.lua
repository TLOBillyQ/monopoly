local number_utils = require("src.foundation.number")
local runtime_state = require("src.ui.state.runtime")
local choice_support = require("src.ui.view.choice_support")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local modal_ports = require("src.ui.input.modal_ports")

local item_slot_confirm = {}

local _modal_ports = modal_ports.resolve

local function _close_confirm_screen(state)
  local modal = _modal_ports(state)
  if type(modal.close_choice_modal) == "function" then
    modal.close_choice_modal(state)
  end
end

local function _on_slot_choice_select(state, game, intent, opts, action_port)
  local record = pending_confirmation.confirm(state)
  local stored = record and record.intent or nil
  _close_confirm_screen(state)
  if stored then action_port.dispatch_action(game, state, stored, opts) end
end

local _SLOT_CONFIRM_DISPATCH = {
  choice_select = _on_slot_choice_select,
  choice_cancel = function(state)
    pending_confirmation.cancel(state)
    _close_confirm_screen(state)
  end,
}

function item_slot_confirm.dispatch(state, game, intent, opts, action_port)
  if not pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_ITEM_SLOT) then return false end
  local intent_type = intent and intent.type
  local handler = _SLOT_CONFIRM_DISPATCH[intent_type]
  if not handler then return false end
  handler(state, game, intent, opts, action_port)
  return true
end

local function _resolve_slot_index(intent)
  if not intent or intent.type ~= "ui_button" then return nil end
  local id = intent.id
  if type(id) ~= "string" then return nil end
  return number_utils.to_integer(string.match(id, "^item_slot_(%d+)$"))
end

local function _resolve_slot_option(state, index)
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  local slot = choice_support.find_confirmable_slot(choice, index)
  if not slot then return nil, nil, nil end
  local option = choice_support.resolve_option_by_id(choice, slot.item_id)
  if not option or not option.confirm_title then return nil, nil, nil end
  return choice, slot, option
end

local function _open_slot_confirm_screen(state, modal, choice, slot, option)
  modal.open_pre_confirm_screen(state, choice, slot.item_id, option.confirm_title, option.confirm_body or "")
end

function item_slot_confirm.try_enter(state, intent)
  local index = _resolve_slot_index(intent)
  if not index then return false end
  local choice, slot, option = _resolve_slot_option(state, index)
  if not choice then return false end
  local modal = _modal_ports(state)
  if type(modal.open_pre_confirm_screen) ~= "function" then
    return false
  end
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_SLOT, { intent = intent })
  _open_slot_confirm_screen(state, modal, choice, slot, option)
  return true
end

return item_slot_confirm

--[[ mutate4lua-manifest
version=2
projectHash=38e79dcc301250e6
scope.0.id=chunk:src/ui/input/item_slot_confirm.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=25b2ac56f56dedd9
scope.1.id=function:_close_confirm_state:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=17
scope.1.semanticHash=dc4515eb40055366
scope.2.id=function:_on_slot_choice_select:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=23
scope.2.semanticHash=e4793b0ddb471053
scope.3.id=function:anonymous@27:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=27
scope.3.semanticHash=72760c8eb815c920
scope.4.id=function:item_slot_confirm.dispatch:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=37
scope.4.semanticHash=945a22ccd5147569
scope.5.id=function:_resolve_slot_index:39
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=44
scope.5.semanticHash=9c99472d110fc70e
scope.6.id=function:_find_confirmable_slot:46
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=53
scope.6.semanticHash=426c2c3bbf2fd7e9
scope.7.id=function:_resolve_slot_option:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=61
scope.7.semanticHash=699f59a8b41fc2c8
scope.8.id=function:_open_slot_confirm_screen:63
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=65
scope.8.semanticHash=4c4ee61118fc5409
scope.9.id=function:item_slot_confirm.try_enter:67
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=82
scope.9.semanticHash=da79b7bda564e1f0
]]
