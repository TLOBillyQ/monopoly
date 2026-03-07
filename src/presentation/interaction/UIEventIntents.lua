local logger = require("src.core.utils.Logger")
local runtime_state = require("src.core.runtime_facade.RuntimeState")

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
    local ui_runtime = state and runtime_state.ensure_ui_runtime(state) or nil
    local mapped = ui_runtime and ui_runtime.choice_visible_option_ids and ui_runtime.choice_visible_option_ids[index]
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
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
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
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
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
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice then
    logger.warn(warn_label .. " without choice")
    return nil
  end
  local ui_runtime = runtime_state.ensure_ui_runtime(state)
  local option_id = ui_runtime.pending_choice_selected_option_id
  if option_id == nil and type(ui_runtime.choice_visible_option_ids) == "table" then
    option_id = ui_runtime.choice_visible_option_ids[1]
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
