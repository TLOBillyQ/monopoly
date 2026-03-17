local logger = require("src.core.utils.logger")
local runtime_state = require("src.ui.runtime.runtime_state_seam")

local intents = {}

local function _resolve_option_id_from_payload(payload)
  return payload.option_id or payload.option or nil
end

local function _resolve_index_from_payload(payload)
  return payload.index or payload.option_index or payload.card_index or payload.choice_index
end

local function _resolve_mapped_from_runtime(state, index)
  local ui_runtime = state and runtime_state.ensure_ui_runtime(state) or nil
  return ui_runtime and ui_runtime.choice_visible_option_ids and ui_runtime.choice_visible_option_ids[index]
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
