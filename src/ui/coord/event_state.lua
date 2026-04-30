local runtime = require("src.ui.render.runtime_ui")
local role_id_utils = require("src.foundation.identity.role_id")

local ui_event_state = {}

local function _has_active_modal(ui)
  return ui.market_active or ui.choice_active or ui.popup_active
end

function ui_event_state.is_base_screen_active(state)
  local ui = state and state.ui
  if not ui then
    return false
  end
  if _has_active_modal(ui) then
    return false
  end
  return true
end

function ui_event_state.resolve_event_log_enabled(state, role_id)
  local ui = state and state.ui
  if role_id == nil then
    local role = runtime.get_client_role()
    role_id = runtime.resolve_role_id(role)
  end
  role_id = role_id_utils.normalize(role_id)
  if role_id == nil then
    return false
  end
  local by_role = ui and ui.debug_log_enabled_by_role or nil
  if type(by_role) == "table" then
    return role_id_utils.read(by_role, role_id) == true
  end
  return false
end

return ui_event_state
