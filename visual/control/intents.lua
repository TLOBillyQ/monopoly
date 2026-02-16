local logger = require("core.logger")

local intents = {}

function intents.resolve_option_id(choice, payload, state)
  assert(choice ~= nil, "missing choice")
  assert(payload ~= nil, "missing payload")
  local option_id = payload.option_id or payload.option or nil
  if option_id then
    return option_id
  end
  local index = payload.index or payload.option_index or payload.card_index or payload.choice_index
  if index then
    local mapped = state and state.choice_visible_option_ids and state.choice_visible_option_ids[index]
    if mapped then
      return mapped
    end
    local options = choice.options
    if type(options) ~= "table" then
      return nil
    end
    local option = options[index]
    if option then
      return option.id or option
    end
  end
  return nil
end

function intents.choice_cancel_intent(state, warn_label)
  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
    return nil
  end
  if choice.allow_cancel == false then
    return nil
  end
  return { type = "choice_cancel", choice_id = choice.id }
end

function intents.choice_select_intent(state, index, warn_label)
  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
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
  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
    return nil
  end
  local option_id = state.pending_choice_selected_option_id
  if option_id == nil and type(state.choice_visible_option_ids) == "table" then
    option_id = state.choice_visible_option_ids[1]
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
