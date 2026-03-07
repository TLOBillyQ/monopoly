local logger = require("src.core.utils.logger")
local pre_confirm_flow = require("src.presentation.interaction.ui_intent_dispatcher.pre_confirm_flow")
local item_phase_ask_flow = require("src.presentation.interaction.ui_intent_dispatcher.item_phase_ask_flow")

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

function game_action_dispatcher.dispatch(state, game, intent, opts, action_port, turn_action_helpers)
  local intent_type = intent and intent.type
  if not intent_type then
    return false
  end

  if state._suppress_item_slot_highlight_until_pick == true and _is_item_slot_click(intent) then
    state._suppress_item_slot_highlight_until_pick = nil
  end
  if _is_item_slot_click(intent) then
    state._skip_item_slot_highlight_replay_choice_id = nil
  end

  if item_phase_ask_flow.dispatch(state, game, intent, opts, action_port) then
    return true
  end

  -- pre-confirm: confirmed action from secondary confirm screen
  if state._pre_confirm_active then
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
  end

  -- pre-confirm: intercept fresh selection
  if not state._pre_confirm_active and pre_confirm_flow.needs_pre_confirm(state, intent) then
    if pre_confirm_flow.enter(state, intent) then
      return true
    end
  end

  if intent_type == "ui_button"
      or intent_type == "choice_select"
      or intent_type == "choice_cancel" then
    local action = intent
    if intent_type == "ui_button" and intent.id == "auto" then
      action = turn_action_helpers.normalize_auto_intent(state, intent)
      if action == nil then
        return true
      end
    end
    action_port.dispatch_action(game, state, action, opts)
    return true
  end

  if intent_type == "market_confirm" then
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

  if intent_type == "market_page_prev" or intent_type == "market_page_next" then
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

  if intent_type == "market_tab_select" then
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

  return false
end

return game_action_dispatcher
