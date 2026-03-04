local runtime = require("src.presentation.api.UIRuntimePort")

local ui_event_state = {}

function ui_event_state.is_base_screen_active(state)
  local ui = state and state.ui
  if not ui then
    return false
  end
  if ui.market_active or ui.choice_active or ui.popup_active then
    return false
  end
  return true
end

function ui_event_state.resolve_debug_enabled(state, role_id)
  local ui = state and state.ui
  if role_id == nil then
    local role = runtime.get_client_role()
    role_id = runtime.resolve_role_id(role)
  end
  if role_id == nil then
    return false
  end
  if ui and type(ui.debug_log_enabled_by_role) == "table" then
    return ui.debug_log_enabled_by_role[role_id] == true
  end
  return false
end

return ui_event_state
