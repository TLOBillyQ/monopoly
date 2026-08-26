local logger = require("src.foundation.log")
local pre_confirm_flow = require("src.ui.input.pre_confirm")
local item_phase_ask_flow = require("src.ui.input.item_phase_ask")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local command_policy = require("src.ui.input.command_policy")
local highlight_lifecycle = require("src.ui.state.item_slot_highlight_lifecycle_queue")

local game_action_dispatcher = {}

local function _is_item_slot_click(intent)
  return command_policy.is_item_slot_command(intent)
end

-- #595:槽位命令无条件解冻(玩家已经动过手),与规则结算是否接受无关
-- (场景 015),故在这里登记而不等结算回来。
local function _register_slot_command(state, intent)
  if not _is_item_slot_click(intent) then
    return
  end
  highlight_lifecycle.push(state, "slot_command", intent and intent.choice_id or nil)
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

local function _intent_type(intent)
  return intent and intent.type
end

local function _pre_confirm_handler(intent)
  return _PRE_CONFIRM_HANDLERS[_intent_type(intent)]
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
  if item_phase_ask_flow.dispatch(state, game, intent, opts, ap) then return true end
  return _handle_pre_confirm(state, game, intent, opts, ap)
end

local function _try_enter_pre_confirm(state, intent)
  if pending_confirmation.is_active(state) then return false end
  if not pre_confirm_flow.needs_pre_confirm(state, intent) then return false end
  return pre_confirm_flow.enter(state, intent)
end

local function _try_pipeline_early(state, game, intent, opts, ap)
  if _try_slot_dispatchers(state, game, intent, opts, ap) then return true end
  return _try_enter_pre_confirm(state, intent)
end

function game_action_dispatcher.dispatch(state, game, intent, opts, action_port, turn_action_helpers)
  local intent_type = intent and intent.type
  if not intent_type then return false end
  _register_slot_command(state, intent)
  if _try_pipeline_early(state, game, intent, opts, action_port) then return true end
  return _route_by_policy(state, game, intent, opts, action_port, turn_action_helpers)
end

return game_action_dispatcher

--[[ mutate4lua-manifest
version=4
projectHash=5ee8505f103dad46
scope.0.id=chunk:src/ui/input/game_action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=127
scope.0.semanticHash=2b3c4192254ca5f2
scope.1.id=function:_is_item_slot_click
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=f1ce1850b7232305
scope.2.id=function:_register_slot_command
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=21
scope.2.semanticHash=4a110872872ef24b
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=28
scope.3.semanticHash=aacdcdc73a77e270
scope.4.id=function:<anonymous>#2
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=32
scope.4.semanticHash=99b2300573a2eddc
scope.5.id=function:_intent_type
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=37
scope.5.semanticHash=ac1dbf12b688483f
scope.6.id=function:_pre_confirm_handler
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=41
scope.6.semanticHash=0101d1e07a84b72f
scope.7.id=function:_dispatch_pre_confirm_handler
scope.7.kind=function
scope.7.startLine=43
scope.7.endLine=48
scope.7.semanticHash=1ca0328197181131
scope.8.id=function:_handle_pre_confirm
scope.8.kind=function
scope.8.startLine=50
scope.8.endLine=55
scope.8.semanticHash=64d5be15de89796e
scope.9.id=function:_dispatch_basic_action
scope.9.kind=function
scope.9.startLine=57
scope.9.endLine=67
scope.9.semanticHash=ee78f2e7de417052
scope.10.id=function:_dispatch_market_intent
scope.10.kind=function
scope.10.startLine=69
scope.10.endLine=82
scope.10.semanticHash=50341cdb41a8bf7d
scope.11.id=function:<anonymous>#3
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=89
scope.11.semanticHash=b838e1e2dd3b62af
scope.12.id=function:<anonymous>#4
scope.12.kind=function
scope.12.startLine=90
scope.12.endLine=90
scope.12.semanticHash=7237368930dafdd4
scope.13.id=function:<anonymous>#5
scope.13.kind=function
scope.13.startLine=91
scope.13.endLine=91
scope.13.semanticHash=7237368930dafdd4
scope.14.id=function:<anonymous>#6
scope.14.kind=function
scope.14.startLine=92
scope.14.endLine=92
scope.14.semanticHash=7237368930dafdd4
scope.15.id=function:<anonymous>#7
scope.15.kind=function
scope.15.startLine=93
scope.15.endLine=93
scope.15.semanticHash=7237368930dafdd4
scope.16.id=function:_route_by_policy
scope.16.kind=function
scope.16.startLine=96
scope.16.endLine=100
scope.16.semanticHash=5e2f5a8f1bce91d3
scope.17.id=function:_try_slot_dispatchers
scope.17.kind=function
scope.17.startLine=102
scope.17.endLine=105
scope.17.semanticHash=5284fad69fbef80f
scope.18.id=function:_try_enter_pre_confirm
scope.18.kind=function
scope.18.startLine=107
scope.18.endLine=111
scope.18.semanticHash=d497482bdc4607d0
scope.19.id=function:_try_pipeline_early
scope.19.kind=function
scope.19.startLine=113
scope.19.endLine=116
scope.19.semanticHash=781c8d9de0cc06ba
scope.20.id=function:game_action_dispatcher.dispatch
scope.20.kind=function
scope.20.startLine=118
scope.20.endLine=124
scope.20.semanticHash=4d39354aadd7915f
]]
