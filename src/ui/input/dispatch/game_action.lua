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

local function _handle_pre_confirm(state, game, intent, opts, action_port)
  local intent_type = intent and intent.type
  if not state._pre_confirm_active then
    return false
  end
  if intent_type == "choice_select" then
    state._pre_confirm_active = nil
    state._pre_confirm_source_screen = nil
    action_port.dispatch_action(game, state, intent, opts)
    return true
  end
  if intent_type == "choice_cancel" then
    pre_confirm_flow.cancel(state)
    return true
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

local function _dispatch_market_confirm(game, state, intent, opts, action_port)
  if not intent.choice_id or not intent.option_id then
    logger.warn("market_confirm missing ids:", tostring(intent.choice_id), tostring(intent.option_id))
    return true
  end
  action_port.dispatch_action(game, state, {
    type = "choice_select",
    choice_id = intent.choice_id,
    option_id = intent.option_id,
    actor_role_id = intent.actor_role_id,
  }, opts)
  return true
end

local function _dispatch_market_page(intent_type, game, state, intent, opts, action_port)
  if not intent.choice_id then
    logger.warn(intent_type .. " missing choice_id")
    return true
  end
  action_port.dispatch_action(game, state, {
    type = intent_type,
    choice_id = intent.choice_id,
    actor_role_id = intent.actor_role_id,
  }, opts)
  return true
end

local function _dispatch_market_tab(game, state, intent, opts, action_port)
  if not intent.choice_id or not intent.tab then
    logger.warn("market_tab_select missing payload:", tostring(intent.choice_id), tostring(intent.tab))
    return true
  end
  action_port.dispatch_action(game, state, {
    type = "market_tab_select",
    choice_id = intent.choice_id,
    tab = intent.tab,
    actor_role_id = intent.actor_role_id,
  }, opts)
  return true
end

local _INTENT_HANDLERS = {
  ui_button      = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  choice_select  = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  choice_cancel  = function(s, g, i, o, ap, h) return _dispatch_basic_action(s, g, i, o, ap, h) end,
  market_confirm    = function(s, g, i, o, ap) return _dispatch_market_confirm(g, s, i, o, ap) end,
  market_page_prev  = function(s, g, i, o, ap) return _dispatch_market_page("market_page_prev", g, s, i, o, ap) end,
  market_page_next  = function(s, g, i, o, ap) return _dispatch_market_page("market_page_next", g, s, i, o, ap) end,
  market_tab_select = function(s, g, i, o, ap) return _dispatch_market_tab(g, s, i, o, ap) end,
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
