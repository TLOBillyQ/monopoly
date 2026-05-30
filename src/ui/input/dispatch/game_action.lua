local logger = require("src.foundation.log")
local pre_confirm_flow = require("src.ui.input.dispatch.pre_confirm")
local item_phase_ask_flow = require("src.ui.input.dispatch.item_phase_ask")
local item_slot_confirm = require("src.ui.input.dispatch.item_slot_confirm")

local game_action_dispatcher = {}

local function _is_item_slot_click(intent)
  if not intent or intent.type ~= "ui_button" then
    return false
  end
  if type(intent.id) ~= "string" then
    return false
  end
  return string.match(intent.id, "^item_slot_%d+$") ~= nil
end

local function _normalize_item_slot_flags(state, intent)
  if not _is_item_slot_click(intent) then
    return
  end
  if state._suppress_item_slot_highlight_until_pick == true then
    state._suppress_item_slot_highlight_until_pick = nil
  end
  state._skip_item_slot_highlight_replay_choice_id = nil
end

local _PRE_CONFIRM_HANDLERS = {
  choice_select = function(state, game, intent, opts, action_port)
    state._pre_confirm_active = nil
    state._pre_confirm_source_screen = nil
    action_port.dispatch_action(game, state, intent, opts)
    return true
  end,
  choice_cancel = function(state)
    pre_confirm_flow.cancel(state)
    return true
  end,
}

local function _handle_pre_confirm(state, game, intent, opts, action_port)
  if not state._pre_confirm_active then
    return false
  end
  local handler = _PRE_CONFIRM_HANDLERS[intent and intent.type]
  if handler then
    return handler(state, game, intent, opts, action_port)
  end
  return false
end

local function _dispatch_basic_action(state, game, intent, opts, action_port, turn_action_helpers)
  local action = intent
  if intent.type == "ui_button" and intent.id == "auto" then
    action = turn_action_helpers.normalize_auto_intent(state, intent)
    if action == nil then
      return true
    end
  end
  action_port.dispatch_action(game, state, action, opts)
  return true
end

local function _dispatch_market_intent(action_type, required_keys, game, state, intent, opts, action_port)
  for _, key in ipairs(required_keys) do
    if intent[key] == nil then
      logger.warn(intent.type .. " missing " .. key)
      return true
    end
  end
  local payload = { type = action_type, actor_role_id = intent.actor_role_id }
  for _, key in ipairs(required_keys) do
    payload[key] = intent[key]
  end
  action_port.dispatch_action(game, state, payload, opts)
  return true
end

local _MARKET_CONFIRM_KEYS = { "choice_id", "option_id" }
local _MARKET_TAB_KEYS = { "choice_id", "tab" }
local _MARKET_PAGE_KEYS = { "choice_id" }

local _INTENT_HANDLERS = {
  ui_button      = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  choice_select  = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  choice_cancel  = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  market_confirm    = function(s, g, i, o, ap) return _dispatch_market_intent("choice_select", _MARKET_CONFIRM_KEYS, g, s, i, o, ap) end,
  market_page_prev  = function(s, g, i, o, ap) return _dispatch_market_intent("market_page_prev", _MARKET_PAGE_KEYS, g, s, i, o, ap) end,
  market_page_next  = function(s, g, i, o, ap) return _dispatch_market_intent("market_page_next", _MARKET_PAGE_KEYS, g, s, i, o, ap) end,
  market_tab_select = function(s, g, i, o, ap) return _dispatch_market_intent("market_tab_select", _MARKET_TAB_KEYS, g, s, i, o, ap) end,
}

local function _route_by_intent_type(intent_type, state, game, intent, opts, action_port, helpers)
  local handler = _INTENT_HANDLERS[intent_type]
  if handler then return handler(state, game, intent, opts, action_port, helpers) end
  return false
end

local function _try_slot_dispatchers(state, game, intent, opts, ap)
  if item_slot_confirm.dispatch(state, game, intent, opts, ap) then return true end
  if item_phase_ask_flow.dispatch(state, game, intent, opts, ap) then return true end
  return _handle_pre_confirm(state, game, intent, opts, ap)
end

local function _try_enter_pre_confirm(state, intent)
  if state._pre_confirm_active then return false end
  if not pre_confirm_flow.needs_pre_confirm(state, intent) then return false end
  return pre_confirm_flow.enter(state, intent)
end

local function _try_item_slot(state, intent)
  return _is_item_slot_click(intent) and item_slot_confirm.try_enter(state, intent)
end

local function _try_pipeline_early(state, game, intent, opts, ap)
  if _try_slot_dispatchers(state, game, intent, opts, ap) then return true end
  if _try_enter_pre_confirm(state, intent) then return true end
  return _try_item_slot(state, intent) == true
end

function game_action_dispatcher.dispatch(state, game, intent, opts, action_port, turn_action_helpers)
  local intent_type = intent and intent.type
  if not intent_type then return false end
  _normalize_item_slot_flags(state, intent)
  if _try_pipeline_early(state, game, intent, opts, action_port) then return true end
  return _route_by_intent_type(intent_type, state, game, intent, opts, action_port, turn_action_helpers)
end

return game_action_dispatcher

--[[ mutate4lua-manifest
version=2
projectHash=4d0e983eccbb7a55
scope.0.id=chunk:src/ui/input/dispatch/game_action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=124
scope.0.semanticHash=102ca25305aaa693
scope.1.id=function:_is_item_slot_click:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=16
scope.1.semanticHash=f49e82f727702e1f
scope.2.id=function:_normalize_item_slot_flags:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=9a3c431f6c88f71f
scope.3.id=function:_handle_pre_confirm:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=44
scope.3.semanticHash=3f63f3312f92eb9d
scope.4.id=function:_dispatch_basic_action:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=56
scope.4.semanticHash=41cdcb573a781138
scope.5.id=function:anonymous@78:78
scope.5.kind=function
scope.5.startLine=78
scope.5.endLine=78
scope.5.semanticHash=205d4c41d9f5849d
scope.6.id=function:anonymous@79:79
scope.6.kind=function
scope.6.startLine=79
scope.6.endLine=79
scope.6.semanticHash=205d4c41d9f5849d
scope.7.id=function:anonymous@80:80
scope.7.kind=function
scope.7.startLine=80
scope.7.endLine=80
scope.7.semanticHash=205d4c41d9f5849d
scope.8.id=function:anonymous@81:81
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=81
scope.8.semanticHash=af3e08d3f990b5c8
scope.9.id=function:anonymous@82:82
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=82
scope.9.semanticHash=8c6d309062f518ad
scope.10.id=function:anonymous@83:83
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=83
scope.10.semanticHash=7d454d90e12331cd
scope.11.id=function:anonymous@84:84
scope.11.kind=function
scope.11.startLine=84
scope.11.endLine=84
scope.11.semanticHash=fb5d684eb166e51c
scope.12.id=function:_route_by_intent_type:87
scope.12.kind=function
scope.12.startLine=87
scope.12.endLine=91
scope.12.semanticHash=2e9701d901d993bd
scope.13.id=function:_try_slot_dispatchers:93
scope.13.kind=function
scope.13.startLine=93
scope.13.endLine=97
scope.13.semanticHash=dee4ae9b68de961b
scope.14.id=function:_try_enter_pre_confirm:99
scope.14.kind=function
scope.14.startLine=99
scope.14.endLine=103
scope.14.semanticHash=491bbe11cfb36234
scope.15.id=function:_try_item_slot:105
scope.15.kind=function
scope.15.startLine=105
scope.15.endLine=107
scope.15.semanticHash=8b1ea1265c56967f
scope.16.id=function:_try_pipeline_early:109
scope.16.kind=function
scope.16.startLine=109
scope.16.endLine=113
scope.16.semanticHash=701ed92e73e6c510
scope.17.id=function:game_action_dispatcher.dispatch:115
scope.17.kind=function
scope.17.startLine=115
scope.17.endLine=121
scope.17.semanticHash=7b93cbdc1ef47ce7
]]
