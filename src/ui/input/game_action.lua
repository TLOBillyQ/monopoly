local logger = require("src.foundation.log")
local pre_confirm_flow = require("src.ui.input.pre_confirm")
local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
local item_slot_confirm = require("src.ui.input.item_slot_confirm")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local command_policy = require("src.ui.input.command_policy")

local game_action_dispatcher = {}

local function _is_item_slot_click(intent)
  return command_policy.is_item_slot_command(intent)
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
    pending_confirmation.confirm(state)
    action_port.dispatch_action(game, state, intent, opts)
    return true
  end,
  choice_cancel = function(state)
    pre_confirm_flow.cancel(state)
    return true
  end,
}

local function _pre_confirm_handler(intent)
  return _PRE_CONFIRM_HANDLERS[intent and intent.type]
end

local function _dispatch_pre_confirm_handler(handler, state, game, intent, opts, action_port)
  if handler == nil then
    return false
  end
  return handler(state, game, intent, opts, action_port)
end

local function _handle_pre_confirm(state, game, intent, opts, action_port)
  if not pending_confirmation.is_source_active(state, pending_confirmation.SOURCE_CHOICE_SELECT) then
    return false
  end
  return _dispatch_pre_confirm_handler(_pre_confirm_handler(intent), state, game, intent, opts, action_port)
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

local _COMMAND_HANDLERS = {
  basic = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  market_confirm    = function(s, g, i, o, ap) return _dispatch_market_intent("choice_select", _MARKET_CONFIRM_KEYS, g, s, i, o, ap) end,
  market_page_prev  = function(s, g, i, o, ap) return _dispatch_market_intent("market_page_prev", _MARKET_PAGE_KEYS, g, s, i, o, ap) end,
  market_page_next  = function(s, g, i, o, ap) return _dispatch_market_intent("market_page_next", _MARKET_PAGE_KEYS, g, s, i, o, ap) end,
  market_tab_select = function(s, g, i, o, ap) return _dispatch_market_intent("market_tab_select", _MARKET_TAB_KEYS, g, s, i, o, ap) end,
}

local function _route_by_policy(state, game, intent, opts, action_port, helpers)
  local handler = _COMMAND_HANDLERS[command_policy.game_handler(intent)]
  if handler then return handler(state, game, intent, opts, action_port, helpers) end
  return false
end

local function _try_slot_dispatchers(state, game, intent, opts, ap)
  if item_slot_confirm.dispatch(state, game, intent, opts, ap) then return true end
  if item_phase_ask_flow.dispatch(state, game, intent, opts, ap) then return true end
  return _handle_pre_confirm(state, game, intent, opts, ap)
end

local function _try_enter_pre_confirm(state, intent)
  if pending_confirmation.is_active(state) then return false end
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
  return _route_by_policy(state, game, intent, opts, action_port, turn_action_helpers)
end

return game_action_dispatcher

--[[ mutate4lua-manifest
version=2
projectHash=064fb9ac9edb178d
scope.0.id=chunk:src/ui/input/game_action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=130
scope.0.semanticHash=ab4e68c3bb72dd79
scope.1.id=function:_is_item_slot_click:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=2f5a6fa892d4c6fa
scope.2.id=function:_normalize_item_slot_flags:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=21
scope.2.semanticHash=9a3c431f6c88f71f
scope.3.id=function:anonymous@24:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=29
scope.3.semanticHash=dac33711b90763f3
scope.4.id=function:anonymous@30:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=33
scope.4.semanticHash=4f9c96f80818b577
scope.5.id=function:_pre_confirm_handler:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=dc57be83a18a4cbb
scope.6.id=function:_dispatch_pre_confirm_handler:40
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=45
scope.6.semanticHash=bf3980c467c5629a
scope.7.id=function:_handle_pre_confirm:47
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=52
scope.7.semanticHash=e325a3f9566f9e22
scope.8.id=function:_dispatch_basic_action:54
scope.8.kind=function
scope.8.startLine=54
scope.8.endLine=64
scope.8.semanticHash=41cdcb573a781138
scope.9.id=function:anonymous@86:86
scope.9.kind=function
scope.9.startLine=86
scope.9.endLine=86
scope.9.semanticHash=205d4c41d9f5849d
scope.10.id=function:anonymous@87:87
scope.10.kind=function
scope.10.startLine=87
scope.10.endLine=87
scope.10.semanticHash=af3e08d3f990b5c8
scope.11.id=function:anonymous@88:88
scope.11.kind=function
scope.11.startLine=88
scope.11.endLine=88
scope.11.semanticHash=8c6d309062f518ad
scope.12.id=function:anonymous@89:89
scope.12.kind=function
scope.12.startLine=89
scope.12.endLine=89
scope.12.semanticHash=7d454d90e12331cd
scope.13.id=function:anonymous@90:90
scope.13.kind=function
scope.13.startLine=90
scope.13.endLine=90
scope.13.semanticHash=fb5d684eb166e51c
scope.14.id=function:_route_by_policy:93
scope.14.kind=function
scope.14.startLine=93
scope.14.endLine=97
scope.14.semanticHash=07463c8b3bf084c5
scope.15.id=function:_try_slot_dispatchers:99
scope.15.kind=function
scope.15.startLine=99
scope.15.endLine=103
scope.15.semanticHash=dee4ae9b68de961b
scope.16.id=function:_try_enter_pre_confirm:105
scope.16.kind=function
scope.16.startLine=105
scope.16.endLine=109
scope.16.semanticHash=491bbe11cfb36234
scope.17.id=function:_try_item_slot:111
scope.17.kind=function
scope.17.startLine=111
scope.17.endLine=113
scope.17.semanticHash=8b1ea1265c56967f
scope.18.id=function:_try_pipeline_early:115
scope.18.kind=function
scope.18.startLine=115
scope.18.endLine=119
scope.18.semanticHash=701ed92e73e6c510
scope.19.id=function:game_action_dispatcher.dispatch:121
scope.19.kind=function
scope.19.startLine=121
scope.19.endLine=127
scope.19.semanticHash=4dc1013f6a87f569
]]
